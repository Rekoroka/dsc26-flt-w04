import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:flutter/material.dart';

class StopTile extends StatelessWidget {
  const StopTile({
    super.key,
    required this.stop,
    required this.onTap,
    required this.onCall,
  });

  final Stop stop;
  final VoidCallback onTap;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final color = switch (stop.status) {
      StopStatus.pending => Colors.amber.shade700,
      StopStatus.delivered => Colors.green.shade700,
      StopStatus.failed => Colors.red.shade700,
    };

    return ListTile(
      onTap: onTap,

      leading: Container(
        key: Key('stop-dot-${stop.id}'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        stop.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      subtitle: Text(stop.address),

      trailing: IconButton(
        key: Key('call-${stop.id}'),
        icon: const Icon(Icons.call),
        tooltip: 'Call ${stop.customerName}',
        onPressed: onCall,
      ),
    );
  }
}
