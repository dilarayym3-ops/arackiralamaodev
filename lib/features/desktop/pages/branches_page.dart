import 'package:flutter/material.dart';
import '../../../data/repositories/sube_repository.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});
  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  final _repo = SubeRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final fAdi = TextEditingController();
  final fAdres = TextEditingController();
  final fTel = TextEditingController();
  final fIl = TextEditingController();
  final fIlce = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      final all = await _repo.getAll();
      final term = _q.text.trim().toLowerCase();
      _items = term.isEmpty
          ? all
          : all.where((e) =>
              (e['SUBE_ADI'] ?? '').toString().toLowerCase().contains(term) ||
              (e['IL'] ?? '').toString().toLowerCase().contains(term) ||
              (e['ILCE'] ?? '').toString().toLowerCase().contains(term)
            ).toList();
    } catch (e) { _error = e.toString(); }
    finally { setState(() => _loading = false); }
  }

  Future<void> _fill(Map<String, dynamic> m) async {
    setState(() => _selected = m);
    fAdi.text = m['SUBE_ADI'] ?? '';
    // Adres ve telefon dolmazsa fallback çalışanın telefonu
    final adres = (m['ADRES'] ?? '').toString();
    final tel = (m['TELEFON'] ?? '').toString();
    fAdres.text = adres;
    if (tel.isEmpty) {
      final fb = await _repo.getFallbackPhoneForBranch(m['SUBE_ID'] as int);
      fTel.text = (fb?['TELEFON'] ?? '').toString();
    } else {
      fTel.text = tel;
    }
    fIl.text = m['IL'] ?? '';
    fIlce.text = m['ILCE'] ?? '';
  }

  void _clear() { setState(() => _selected = null); fAdi.clear(); fAdres.clear(); fTel.clear(); fIl.clear(); fIlce.clear(); }

  Future<void> _create() async {
    try {
      await _repo.create(
        subeAdi: fAdi.text.trim(),
        adres: fAdres.text.trim(),
        telefon: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        il: fIl.text.trim(),
        ilce: fIlce.text.trim(),
      );
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şube eklendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        subeId: _selected!['SUBE_ID'] as int,
        subeAdi: fAdi.text.trim(),
        adres: fAdres.text.trim(),
        telefon: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        il: fIl.text.trim(),
        ilce: fIlce.text.trim(),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şube güncellendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['SUBE_ID'] as int);
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şube silindi')));
    } catch (e) { if (mounted) _err(e); }
  }

  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Şube/İl/İlçe ara', border: OutlineInputBorder()), onSubmitted: (_) => _load())),
            const SizedBox(width: 8),
            FilledButton(onPressed: _load, child: const Text('Ara')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () { _q.clear(); _load(); }, child: const Text('Temizle')),
          ]),
        ),
        Expanded(
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
                          tileColor: (_selected?['SUBE_ID'] == m['SUBE_ID']) ? Colors.indigo.withOpacity(.08) : null,
                          leading: const Icon(Icons.home_work),
                          title: Text(m['SUBE_ADI'] ?? ''),
                          subtitle: Text('${m['IL'] ?? ''} / ${m['ILCE'] ?? ''}'),
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
          Text(_selected == null ? 'Şube Ekle' : 'Şube Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: fAdi, decoration: const InputDecoration(labelText: 'Şube Adı', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fAdres, maxLines: 2, decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fTel, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fIl, decoration: const InputDecoration(labelText: 'İl', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fIlce, decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder())),
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