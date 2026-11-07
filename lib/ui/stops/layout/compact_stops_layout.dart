import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:dsc26_flt_w04/ui/stops/widgets/stop_list.dart';
import 'package:flutter/material.dart';

class CompactStopsLayout extends StatelessWidget {
  const CompactStopsLayout({
    super.key,
    required this.stops,
    required this.onStopTap,
  });

  final List<Stop> stops;
  final ValueChanged<Stop> onStopTap;

  @override
  Widget build(BuildContext context) {
    return StopList(stops: stops, onTap: onStopTap);
  }
}
