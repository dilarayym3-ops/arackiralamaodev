import 'package:flutter/material.dart';
import '../../../data/repositories/service_repository.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _repo = ServiceRepository();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final fAd = TextEditingController();
  final fTip = TextEditingController();
  final fUcret = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try { _items = await _repo.listAll(q: _q.text.trim().isEmpty ? null : _q.text.trim()); }
    catch (e) { _error = e.toString(); }
    finally { setState(() => _loading = false); }
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fAd.text = m['HIZMET_ADI'] ?? '';
    fTip.text = m['UCRET_TIPI'] ?? '';
    fUcret.text = (m['UCRET'] ?? '').toString();
  }

  void _clear() { setState(() => _selected = null); fAd.clear(); fTip.clear(); fUcret.clear(); }

  Future<void> _create() async {
    try {
      await _repo.create(ad: fAd.text.trim(), ucretTipi: fTip.text.trim(), ucret: double.parse(fUcret.text));
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet eklendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        id: _selected!['HIZMET_ID'] as int,
        ad: fAd.text.trim().isEmpty ? null : fAd.text.trim(),
        ucretTipi: fTip.text.trim().isEmpty ? null : fTip.text.trim(),
        ucret: fUcret.text.trim().isEmpty ? null : double.parse(fUcret.text),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet güncellendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['HIZMET_ID'] as int);
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet silindi')));
    } catch (e) { if (mounted) _err(e); }
  }

  void _err(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _q,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Hizmet ara', border: OutlineInputBorder()),
              onSubmitted: (_) => _load(),
            )),
            const SizedBox(width: 8),
            FilledButton(onPressed: _load, child: const Text('Ara')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () { _q.clear(); _load(); }, child: const Text('Temizle')),
          ]),
        ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _error != null ? Center(child: Text('Hata: $_error'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _items[i];
                  return ListTile(
                    tileColor: (_selected?['HIZMET_ID'] == m['HIZMET_ID']) ? Colors.indigo.withOpacity(.08) : null,
                    leading: const Icon(Icons.miscellaneous_services),
                    title: Text(m['HIZMET_ADI'] ?? ''),
                    subtitle: Text('${m['UCRET_TIPI'] ?? ''} • ${(m['UCRET'] ?? 0)} TL'),
                    onTap: () => _fill(m),
                  );
                },
              ),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_selected == null ? 'Hizmet Ekle' : 'Hizmet Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: fAd, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fTip, decoration: const InputDecoration(labelText: 'Ücret Tipi', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fUcret, decoration: const InputDecoration(labelText: 'Ücret (TL)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(children: [
            if (_selected == null)
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Ekle'))
            else ...[
              FilledButton.icon(onPressed: _update, icon: const Icon(Icons.save), label: const Text('Güncelle')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete), label: const Text('Sil')),
              const SizedBox(width: 8),
              TextButton(onPressed: _clear, child: const Text('Yeni')),
            ],
          ]),
        ]),
      )),
    ]);
  }
}