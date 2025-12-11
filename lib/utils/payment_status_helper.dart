import 'package:flutter/material.dart';

class PaymentStatusHelper {
  static String getStatusText(String status) {
    switch (status) {
      case 'Ödendi':
        return 'ÖDENDİ';
      case 'Kısmi': 
        return 'KISMİ';
      case 'Yok':
        return 'ÖDENMEDİ';
      default: 
        return status. toUpperCase();
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Ödendi': 
        return Colors.green;
      case 'Kısmi': 
        return Colors.orange;
      case 'Yok':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'Ödendi':
        return Icons.check_circle;
      case 'Kısmi':
        return Icons.hourglass_bottom;
      case 'Yok':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  static Widget buildStatusChip(String status) {
    final color = getStatusColor(status);
    final text = getStatusText(status);
    
    return Container(
      padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getStatusIcon(status), size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildPaymentInfo({
    required double total,
    required double paid,
    required String status,
    bool showPayButton = false,
    VoidCallback? onPay,
  }) {
    final kalan = total - paid;
    final color = getStatusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            buildStatusChip(status),
            const SizedBox(width: 8),
            Text('Ödenen: ${paid.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
            if (kalan > 0) ...[
              const SizedBox(width: 8),
              Text(
                'Kalan: ${kalan.toStringAsFixed(2)} TL',
                style: TextStyle(fontSize: 12, color: Colors. red. shade700, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        if (showPayButton && kalan > 0 && onPay != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payments, size: 18),
              label: const Text('Öde'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
      ],
    );
  }
}