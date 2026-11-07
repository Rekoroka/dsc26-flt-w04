import 'dart:convert';
import 'dart:math' show min;

import 'package:http/http.dart' as http;

import '../domain/delivery_outcome.dart';
import 'local_store.dart';

/// The storage key for the whole queue (a JSON document).
const String outboxStorageKey = 'tawseel.outbox.v1';

enum EntryStatus { pending, rejected }

/// One queued outcome. Immutable; the outbox replaces entries with [copyWith].
final class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.outcome,
    this.attempts = 0,
    this.status = EntryStatus.pending,
    this.rejectionReason,
  });

  /// Generated on the phone when the outcome is recorded; sent as the
  /// Idempotency-Key header.
  final String id;
  final DeliveryOutcome outcome;

  /// How many times this entry has been sent, whatever the answer was.
  final int attempts;
  final EntryStatus status;
  final String? rejectionReason;

  OutboxEntry copyWith({
    DeliveryOutcome? outcome,
    int? attempts,
    EntryStatus? status,
    String? rejectionReason,
  }) => OutboxEntry(
    id: id,
    outcome: outcome ?? this.outcome,
    attempts: attempts ?? this.attempts,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'outcome': outcome.toJson(),
    'attempts': attempts,
    'status': status.name,
    'rejectionReason': rejectionReason,
  };

  factory OutboxEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final outcome = json['outcome'];
    final attempts = json['attempts'];
    final status = json['status'];
    final reason = json['rejectionReason'];
    if (id is! String ||
        outcome is! Map ||
        attempts is! int ||
        status is! String ||
        (reason != null && reason is! String)) {
      throw FormatException('bad outbox entry: $json');
    }
    return OutboxEntry(
      id: id,
      outcome: DeliveryOutcome.fromJson(outcome.cast<String, Object?>()),
      attempts: attempts,
      status: EntryStatus.values.byName(status),
      rejectionReason: reason as String?,
    );
  }

  @override
  String toString() =>
      'OutboxEntry($id, ${outcome.parcelId}, attempts: $attempts, ${status.name})';
}

/// What one sync run did.
final class SyncReport {
  const SyncReport({
    required this.sent,
    required this.rejected,
    required this.remaining,
    this.authRequired = false,
    this.retryAfter,
  });

  /// Entries the server accepted in this run (200, 201 or 409).
  final int sent;

  /// Entries the server rejected in this run (400 or 422).
  final int rejected;

  /// Pending entries left after the run.
  final int remaining;

  /// True when the run stopped on a 401.
  final bool authRequired;

  /// Set when the run stopped on a transient failure: wait this long.
  final Duration? retryAfter;

  @override
  String toString() =>
      'SyncReport(sent: $sent, rejected: $rejected, '
      'remaining: $remaining, authRequired: $authRequired, '
      'retryAfter: $retryAfter)';
}

/// 5 s × 2^(n−1), capped at 300 s. [consecutiveFailures] must be at least 1,
/// otherwise throw ArgumentError.
Duration retryDelay(int consecutiveFailures) {
  if (consecutiveFailures < 1) {
    throw ArgumentError.value(
      consecutiveFailures,
      'consecutiveFailures',
      'must be at least 1',
    );
  }
  // من n = 7 وطالع الناتج 300 ثانية، فنحدد الـ exponent بـ 6 قبل الـ shift
  // علشان نتجنب الـ overflow مع الأرقام الكبيرة جداً.
  final exponent = min(consecutiveFailures - 1, 6);
  final seconds = min(5 * (1 << exponent), 300);
  return Duration(seconds: seconds);
}

/// An offline-first queue of delivery outcomes. See the README for the rules.
///
/// Keep the constructor and the public method signatures exactly.
class Outbox {
  Outbox({
    required LocalStore store,
    required http.Client client,
    required Uri baseUrl,
    required String Function() newId,
  }) : _store = store,
       _client = client,
       _baseUrl = baseUrl,
       _newId = newId;

  final LocalStore _store;
  final http.Client _client;
  final Uri _baseUrl;
  final String Function() _newId;

  /// الـ sync الشغال حالياً (للـ single flight). null = مفيش sync شغال.
  Future<SyncReport>? _running;

  /// طابور (mutex): كل عملية قراءة-تعديل-كتابة على الـ queue بتستنى اللي قبلها.
  Future<void> _tail = Future<void>.value();

  // ---------------------------------------------------------------- record

  /// Validates, queues (or corrects), and persists before completing.
  Future<OutboxEntry> record(DeliveryOutcome outcome) async {
    _validate(outcome);

    return _serial(() async {
      final entries = await _load();

      // Correction: pending + نفس الطرد + عمره ما اتبعت => نستبدله في مكانه.
      final i = entries.indexWhere(
        (e) =>
            e.status == EntryStatus.pending &&
            e.outcome.parcelId == outcome.parcelId &&
            e.attempts == 0,
      );

      final OutboxEntry result;
      if (i >= 0) {
        result = entries[i].copyWith(outcome: outcome); // نفس id ونفس المكان
        entries[i] = result;
      } else {
        result = OutboxEntry(id: _newId(), outcome: outcome); // newId هنا بس
        entries.add(result);
      }

      await _save(entries); // await قبل ما نرجّع
      return result;
    });
  }

  void _validate(DeliveryOutcome o) {
    if (o.parcelId.isEmpty) {
      throw ArgumentError.value(o.parcelId, 'parcelId', 'must not be empty');
    }
    if (!o.recordedAt.isUtc) {
      throw ArgumentError.value(o.recordedAt, 'recordedAt', 'must be UTC');
    }
    switch (o.status) {
      case OutcomeStatus.delivered:
        if (o.codCollectedPiasters < 0) {
          throw ArgumentError.value(
            o.codCollectedPiasters,
            'codCollectedPiasters',
            'must be >= 0',
          );
        }
        if (o.reason != null) {
          throw ArgumentError.value(
            o.reason,
            'reason',
            'a delivered outcome has no reason',
          );
        }
      case OutcomeStatus.failed:
        if (o.reason == null) {
          throw ArgumentError.notNull('reason');
        }
        if (o.codCollectedPiasters != 0) {
          throw ArgumentError.value(
            o.codCollectedPiasters,
            'codCollectedPiasters',
            'a failed outcome collects no cash',
          );
        }
    }
  }

  // ------------------------------------------------------------ the getters

  /// Pending entries, in send order.
  Future<List<OutboxEntry>> pending() async =>
      (await _load()).where((e) => e.status == EntryStatus.pending).toList();

  Future<List<OutboxEntry>> rejected() async =>
      (await _load()).where((e) => e.status == EntryStatus.rejected).toList();

  Future<int> pendingCount() async => (await pending()).length;

  // ------------------------------------------------------------------ sync

  /// Sends pending entries oldest first; single-flight.
  Future<SyncReport> sync() {
    return _running ??= _run().whenComplete(() => _running = null);
  }

  Future<SyncReport> _run() async {
    var sent = 0;
    var rejected = 0;

    Future<SyncReport> stop({
      bool authRequired = false,
      Duration? retryAfter,
    }) async => SyncReport(
      sent: sent,
      rejected: rejected,
      remaining: await pendingCount(),
      authRequired: authRequired,
      retryAfter: retryAfter,
    );

    while (true) {
      // 1) ناخد أقدم pending، نزوّد attempts، ونحفظ *قبل* الإرسال.
      final entry = await _serial<OutboxEntry?>(() async {
        final entries = await _load();
        final i = entries.indexWhere((e) => e.status == EntryStatus.pending);
        if (i < 0) return null;
        final bumped = entries[i].copyWith(attempts: entries[i].attempts + 1);
        entries[i] = bumped;
        await _save(entries);
        return bumped;
      });
      if (entry == null) break; // مفيش حاجة تتبعت

      // 2) الإرسال (برّه الـ lock عشان record تقدر تشتغل أثناء انتظار الشبكة).
      http.Response? response;
      try {
        response = await _client.post(
          _outcomesUrl,
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': entry.id,
          },
          body: utf8.encode(
            jsonEncode({'id': entry.id, ...entry.outcome.toJson()}),
          ),
        );
      } on Exception {
        response = null; // ClientException وأي فشل شبكة = فشل مؤقت
      }

      if (response == null) {
        return stop(retryAfter: retryDelay(entry.attempts));
      }

      // 3) نتعامل مع الرد.
      final code = response.statusCode;
      if (code == 200 || code == 201 || code == 409) {
        await _removeEntry(entry.id);
        sent++;
      } else if (code == 400 || code == 422) {
        await _rejectEntry(entry.id, _reasonFrom(response));
        rejected++;
      } else if (code == 401) {
        return stop(authRequired: true);
      } else {
        return stop(retryAfter: retryDelay(entry.attempts));
      }
    }

    return stop();
  }

  Future<void> _removeEntry(String id) => _serial(() async {
    final entries = await _load();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  });

  Future<void> _rejectEntry(String id, String reason) => _serial(() async {
    final entries = await _load();
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    entries[i] = entries[i].copyWith(
      status: EntryStatus.rejected,
      rejectionReason: reason,
    );
    await _save(entries);
  });

  /// الـ message من الـ JSON لو موجودة، وإلا "HTTP <code>".
  String _reasonFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } on FormatException {
      // الـ body مش JSON: نكمل للقيمة الافتراضية
    }
    return 'HTTP ${response.statusCode}';
  }

  /// {baseUrl}/v1/outcomes (ويشتغل حتى لو الـ baseUrl فيه path أو / في الآخر).
  Uri get _outcomesUrl {
    var base = _baseUrl.path;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return _baseUrl.replace(path: '$base/v1/outcomes');
  }

  // --------------------------------------------------------------- storage

  Future<List<OutboxEntry>> _load() async {
    final raw = await _store.read(outboxStorageKey);
    if (raw == null) return <OutboxEntry>[];
    final list = jsonDecode(raw) as List;
    return [
      for (final e in list)
        OutboxEntry.fromJson((e as Map).cast<String, Object?>()),
    ];
  }

  Future<void> _save(List<OutboxEntry> entries) => _store.write(
    outboxStorageKey,
    jsonEncode([for (final e in entries) e.toJson()]),
  );

  /// بينفّذ العمليات على الـ queue واحدة ورا التانية (مفيش تداخل).
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
