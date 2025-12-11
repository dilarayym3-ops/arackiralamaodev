import 'package:flutter/material.dart';

class PaymentStatusBadge extends StatelessWidget {
  final String status;
  final double?  paidAmount;
  final double? totalAmount;
  final VoidCallback? onPayPressed;

  const PaymentStatusBadge({
    super.key,
    required this. status,
    this.paidAmount,
    this.totalAmount,
    this.onPayPressed,
  });

  Color get _statusColor {
    switch (status. toLowerCase()) {
      case 'ödendi':
      case 'odendi':
        return Colors.green;
      case 'kısmi':
      case 'kismi':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData get _statusIcon {
    switch (status.toLowerCase()) {
      case 'ödendi': 
      case 'odendi': 
        return Icons.check_circle;
      case 'kısmi':
      case 'kismi':
        return Icons.hourglass_bottom;
      default:
        return Icons.cancel;
    }
  }

  String get _displayStatus {
    switch (status. toLowerCase()) {
      case 'ödendi':
      case 'odendi':
        return 'ÖDENDİ';
      case 'kısmi':
      case 'kismi':
        return 'KISMİ';
      case 'yok':
        return 'ÖDENMEDİ';
      default: 
        return status. toUpperCase();
    }
  }

  bool get _showPayButton {
    final s = status.toLowerCase();
    return s == 'yok' || s == 'kısmi' || s == 'kismi' || s == 'ödenmedi' || s == 'odenmedi';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (totalAmount ?? 0) - (paidAmount ?? 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon, color: _statusColor, size: 20),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor),
              ),
              child: Text(
                _displayStatus,
                style: TextStyle(
                  color: _statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (_showPayButton && onPayPressed != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton. icon(
                  onPressed:  onPayPressed,
                  icon: const Icon(Icons.payments, size: 14),
                  label: const Text('Öde', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (paidAmount != null && totalAmount != null) ...[
          const SizedBox(height:  4),
          Text(
            'Ödenen: ${paidAmount! .toStringAsFixed(2)} TL',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (remaining > 0)
            Text(
              'Kalan: ${remaining.toStringAsFixed(2)} TL',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ],
    );
  }
}