import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:dsc26_flt_w04/ui/stops/layout/compact_stops_layout.dart';
import 'package:dsc26_flt_w04/ui/stops/layout/expanded_stops_layout.dart';
import 'package:dsc26_flt_w04/ui/stops/sync_banner.dart';
import 'package:flutter/material.dart';

const double _expandedBreakpoint = 600;

class TawseelStopsApp extends StatefulWidget {
  const TawseelStopsApp({
    super.key,
    required this.stops,
    required this.pendingCount,
    this.textDirection = TextDirection.ltr,
  });

  final List<Stop> stops;
  final int pendingCount;
  final TextDirection textDirection;

  @override
  State<TawseelStopsApp> createState() => _TawseelStopsAppState();
}

class _TawseelStopsAppState extends State<TawseelStopsApp> {
  Object? _selectedId;

  Stop? get _selectedStop {
    if (widget.stops.isEmpty) return null;
    for (final stop in widget.stops) {
      if (stop.id == _selectedId) return stop;
    }
    return widget.stops.first;
  }

  void _selectStop(Stop stop) => setState(() => _selectedId = stop.id);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tawseel stops',
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          Directionality(textDirection: widget.textDirection, child: child!),
      home: Scaffold(
        appBar: AppBar(title: const Text("Today's stops")),
        body: Column(
          children: [
            SyncBanner(
              key: const Key('sync-banner'),
              pendingCount: widget.pendingCount,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= _expandedBreakpoint) {
                    return ExpandedStopsLayout(
                      key: const Key('layout-expanded'),
                      stops: widget.stops,
                      selectedStop: _selectedStop,
                      onStopTap: _selectStop,
                    );
                  }
                  return CompactStopsLayout(
                    key: const Key('layout-compact'),
                    stops: widget.stops,
                    onStopTap: _selectStop,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
