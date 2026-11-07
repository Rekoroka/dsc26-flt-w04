import 'package:flutter/material.dart';

/// شريط يعرض عدد النتائج المنتظرة للمزامنة (Sync).
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    // الرسالة بتتحسب مرة واحدة وتتستخدم في الـ label وفي الـ Text
    final String message;
    if (pendingCount == 0) {
      message = 'All outcomes synced';
    } else if (pendingCount == 1) {
      message = '1 outcome waiting to sync';
    } else {
      message = '$pendingCount outcomes waiting to sync';
    }

    return Semantics(
      liveRegion: true, // قارئ الشاشة يعلن أي تغيير في الرسالة
      label: message,
      excludeSemantics: true, // يتجاهل semantics بتاعة الـ Text (منع التكرار)
      child: Container(
        width: double.infinity,
        color: pendingCount == 0
            ? Colors.green.shade100
            : Colors.orange.shade100,
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 8,
          bottom: 8,
        ),
        child: Text(message),
      ),
    );
  }
}
