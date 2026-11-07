import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:dsc26_flt_w04/ui/stops/stop_tile.dart';
import 'package:flutter/material.dart';

class StopList extends StatelessWidget {
  const StopList({super.key, required this.stops, required this.onTap});

  final List<Stop> stops;
  final ValueChanged<Stop> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: stops.length,
      itemBuilder: (context, i) {
        final stop = stops[i];

        return StopTile(
          key: Key('stop-${stop.id}'),
          stop: stop,
          onTap: () => onTap(stop),
          onCall: () {},
        );
      },
    );
  }
}
