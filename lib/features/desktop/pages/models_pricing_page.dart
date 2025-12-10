import 'package:flutter/material.dart';
import '../../../data/repositories/model_repository.dart';

class ModelsPricingPage extends StatefulWidget {
  const ModelsPricingPage({super.key});

  @override
  State<ModelsPricingPage> createState() => _ModelsPricingPageState();
}

class _ModelsPricingPageState extends State<ModelsPricingPage> {
  final _repo = ModelRepository();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  final fGunluk = TextEditingController();
  final fDepo = TextEditingController();
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      _items = await _repo.listAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fGunluk.text = (m['GUNLUK_KIRA_BEDELI'] as num).toString();
    fDepo.text = (m['DEPOZITO_UCRETI'] as num).toString();
  }

  Future<void> _save() async {
    if (_selected == null) return;
    try {
      await _repo.updatePricing(
        modelId: _selected!['MODEL_ID'] as int,
        gunluk: double.parse(fGunluk.text),
        depozito: double.parse(fDepo.text),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiyat/depozito güncellendi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Hata: $_error'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return ListTile(
                          title: Text('${m['Marka']} ${m['Model']} (${m['Yil']})'),
                          subtitle: Text('Günlük: ${(m['GUNLUK_KIRA_BEDELI'] as num)} TL • Depozito: ${(m['DEPOZITO_UCRETI'] as num)} TL'),
                          onTap: () => _fill(m),
                        );
                      },
                    ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selected == null ? 'Model seçiniz' : 'Fiyat Güncelle',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: fGunluk, decoration: const InputDecoration(labelText: 'Günlük Kira (TL)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: fDepo, decoration: const InputDecoration(labelText: 'Depozito (TL)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _selected == null ? null : _save, icon: const Icon(Icons.save), label: const Text('Kaydet')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}