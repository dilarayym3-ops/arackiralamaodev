import 'package:flutter/material.dart';

class FilterItem {
  final String label;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String? > onChanged;

  FilterItem({
    required this.label,
    required this.options,
    this.selectedValue,
    required this.onChanged,
  });
}

class FilterPanel extends StatelessWidget {
  final List<FilterItem> filters;
  final VoidCallback?  onClearAll;
  final String? searchHint;
  final TextEditingController? searchController;
  final VoidCallback? onSearch;

  const FilterPanel({
    super.key,
    required this.filters,
    this. onClearAll,
    this.searchHint,
    this.searchController,
    this. onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchController != null) ...[
            Row(
              children: [
                Expanded(
                  child:  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: searchHint ?? 'Ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSearch?.call(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons. search, size: 18),
                  label: const Text('Ara'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('Filtreler:', style: TextStyle(fontWeight:  FontWeight.bold)),
              const Spacer(),
              if (onClearAll != null)
                TextButton. icon(
                  onPressed:  onClearAll,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Temizle'),
                ),
            ],
          ),
          const SizedBox(height:  8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: filters.map((f) => _buildFilterDropdown(f)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(FilterItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${item.label}:  ', style: const TextStyle(fontSize: 13)),
        DropdownButton<String>(
          value: item.selectedValue,
          hint: const Text('Tümü'),
          isDense: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Tümü')),
            ...item. options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
          ],
          onChanged: item.onChanged,
        ),
      ],
    );
  }
}