import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:dsc26_flt_w04/ui/stops/widgets/stop_details.dart';
import 'package:dsc26_flt_w04/ui/stops/widgets/stop_list.dart';
import 'package:flutter/material.dart';

class ExpandedStopsLayout extends StatelessWidget {
  const ExpandedStopsLayout({
    super.key,
    required this.stops,
    this.selectedStop,
    required this.onStopTap,
  });

  final List<Stop> stops;
  final Stop? selectedStop;
  final ValueChanged<Stop> onStopTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StopList(stops: stops, onTap: onStopTap),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: StopDetails(
            key: const Key('stop-detail'),
            selectedStop: selectedStop,
          ),
        ),
      ],
    );
  }
}
