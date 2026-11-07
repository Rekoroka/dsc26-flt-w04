import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:flutter/material.dart';

class StopDetails extends StatelessWidget {
  const StopDetails({super.key, required this.selectedStop});

  final Stop? selectedStop;

  @override
  Widget build(BuildContext context) {
    final stop = selectedStop;
    if (stop == null) {
      return const Center(child: Text('No stop selected'));
    }

    return SingleChildScrollView(
      key: const Key('stop-detail'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stop.customerName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(stop.address),
          const SizedBox(height: 8),
          Text(stop.status.name),
        ],
      ),
    );
  }
}
