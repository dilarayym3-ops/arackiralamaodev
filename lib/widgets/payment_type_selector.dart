import 'package:flutter/material.dart';

class PaymentTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;

  const PaymentTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  static const List<String> types = ['Nakit', 'Kart', 'Havale', 'EFT'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ödeme Tipi', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = selectedType == type;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getIcon(type), size: 18),
                  const SizedBox(width: 4),
                  Text(type),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(type),
              selectedColor: Colors.indigo. shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'Nakit': 
        return Icons.money;
      case 'Kart':
        return Icons.credit_card;
      case 'Havale':
        return Icons. account_balance;
      case 'EFT':
        return Icons.swap_horiz;
      default: 
        return Icons.payment;
    }
  }
}