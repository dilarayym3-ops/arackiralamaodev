import 'package:flutter/material.dart';

/// Ödeme tipi seçim dialogu (Nakit / Kart / Havale)
class PaymentTypeDialog {
  /// Ödeme tipi seçimi için dialog göster
  /// Returns: Seçilen ödeme tipi ('Nakit', 'Kart', 'Havale') veya null (iptal)
  static Future<String?> show({
    required BuildContext context,
    String? title,
    String? message,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title ?? 'Ödeme Tipi Seçin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 16),
              ],
              const Text(
                'Ödeme hangi yöntemle yapılacak?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _PaymentTypeButton(
                icon: Icons.money,
                label: 'Nakit',
                color: Colors.green,
                onPressed: () => Navigator.of(context).pop('Nakit'),
              ),
              const SizedBox(height: 8),
              _PaymentTypeButton(
                icon: Icons.credit_card,
                label: 'Kart',
                color: Colors.blue,
                onPressed: () => Navigator.of(context).pop('Kart'),
              ),
              const SizedBox(height: 8),
              _PaymentTypeButton(
                icon: Icons.account_balance,
                label: 'Havale',
                color: Colors.orange,
                onPressed: () => Navigator.of(context).pop('Havale'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PaymentTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: TextStyle(color: color, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          side: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}
