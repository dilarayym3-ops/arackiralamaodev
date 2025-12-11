import 'package:flutter/material.dart';

class PaymentTypeDialog extends StatefulWidget {
  final String title;
  final String message;

  const PaymentTypeDialog({
    super.key,
    required this.title,
    required this.message,
  });

  // Sayfalardaki kullanım ile uyumlu: String? döndürür (Nakit/Kart/Havale)
  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => PaymentTypeDialog(title: title, message: message),
    );
  }

  @override
  State<PaymentTypeDialog> createState() => _PaymentTypeDialogState();
}

class _PaymentTypeDialogState extends State<PaymentTypeDialog> {
  String _selectedType = 'Nakit';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.payments, color: Colors.green),
          SizedBox(width: 8),
          // Başlık parametreden gelecek
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.message),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Ödeme Tipi Seçin:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip('Nakit', Icons.money),
              _buildTypeChip('Kart', Icons.credit_card),
              _buildTypeChip('Havale', Icons.account_balance),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_selectedType),
          icon: const Icon(Icons.check),
          label: const Text('Seç'),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    final selected = _selectedType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(type),
        ],
      ),
      selected: selected,
      onSelected: (_) => setState(() => _selectedType = type),
      selectedColor: Colors.green,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }
}