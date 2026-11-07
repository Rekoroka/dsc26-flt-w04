import 'package:dsc26_flt_w04/domain/stop.dart';
import 'package:flutter/material.dart';

/// لوحة تفاصيل المحطة المختارة (الـ layout الواسع فقط).
class StopDetails extends StatelessWidget {
  const StopDetails({super.key, required this.selectedStop});

  final Stop? selectedStop; // null لو القائمة فاضية

  @override
  Widget build(BuildContext context) {
    final stop = selectedStop; // نسخة محلية عشان Dart تعمل Type Promotion
    if (stop == null) {
      return const Center(child: Text('No stop selected'));
    }

    // SingleChildScrollView: لو الخط كبر والمحتوى زاد، يعمل scroll بدل overflow
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // لازم النص يكون customerName بالظبط من غير أي إضافة
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
