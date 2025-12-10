import 'package:flutter/material.dart';

typedef ItemToString = String Function(Map<String, dynamic> item);
typedef ItemSubtitle = String Function(Map<String, dynamic> item);

class SearchSelectDialog extends StatefulWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> Function(String query) loader;
  final ItemToString itemTitle;
  final ItemSubtitle? itemSubtitle;

  const SearchSelectDialog({
    super.key,
    required this.title,
    required this.loader,
    required this.itemTitle,
    this.itemSubtitle,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String title,
    required Future<List<Map<String, dynamic>>> Function(String query) loader,
    required ItemToString itemTitle,
    ItemSubtitle? itemSubtitle,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        child: SearchSelectDialog(
          title: title,
          loader: loader,
          itemTitle: itemTitle,
          itemSubtitle: itemSubtitle,
        ),
      ),
    );
  }

  @override
  State<SearchSelectDialog> createState() => _SearchSelectDialogState();
}

class _SearchSelectDialogState extends State<SearchSelectDialog> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      _items = await widget.loader(query.trim());
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 620),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _q,
              decoration: const InputDecoration(
                hintText: 'Ara...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _load,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Hata: $_error'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = _items[i];
                            return ListTile(
                              leading: const Icon(Icons.search, color: Colors.indigo),
                              title: Text(widget.itemTitle(m)),
                              subtitle: widget.itemSubtitle == null ? null : Text(widget.itemSubtitle!(m)),
                              onTap: () => Navigator.pop(context, m),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}