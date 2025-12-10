import 'package:flutter/material.dart';
import '../../../data/repositories/customer_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _repo = CustomerRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final fTc = TextEditingController();
  final fEhliyet = TextEditingController();
  final fAd = TextEditingController();
  final fSoyad = TextEditingController();
  final fTel = TextEditingController();
  final fEmail = TextEditingController();
  final fAdres = TextEditingController();
  final fDurum = TextEditingController(text: 'Aktif');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      final all = await _repo.listAll(q: _q.text.trim().isEmpty ? null : _q.text.trim());
      _items = all;
    } catch (e) { _error = e.toString(); }
    finally { setState(() => _loading = false); }
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fTc.text = m['TC_NO'] ?? '';
    fEhliyet.text = m['EHLIYET_ID'] ?? '';
    fAd.text = m['AD'] ?? '';
    fSoyad.text = m['SOYAD'] ?? '';
    fTel.text = m['TELEFON'] ?? '';
    fEmail.text = m['E-MAIL'] ?? '';
    fAdres.text = m['ADRES'] ?? '';
    fDurum.text = m['DURUM'] ?? 'Aktif';
  }

  void _clear() {
    setState(() => _selected = null);
    fTc.clear(); fEhliyet.clear(); fAd.clear(); fSoyad.clear(); fTel.clear(); fEmail.clear(); fAdres.clear(); fDurum.text = 'Aktif';
  }

  Future<void> _create() async {
    try {
      await _repo.create(
        tc: fTc.text.trim(),
        ehliyet: fEhliyet.text.trim(),
        ad: fAd.text.trim(),
        soyad: fSoyad.text.trim(),
        tel: fTel.text.trim(),
        email: fEmail.text.trim(),
        adres: fAdres.text.trim().isEmpty ? null : fAdres.text.trim(),
      );
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müşteri eklendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        id: _selected!['MUSTERI_ID'] as int,
        tel: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        email: fEmail.text.trim().isEmpty ? null : fEmail.text.trim(),
        adres: fAdres.text.trim().isEmpty ? null : fAdres.text.trim(),
        durum: fDurum.text.trim().isEmpty ? null : fDurum.text.trim(),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müşteri güncellendi')));
    } catch (e) { if (mounted) _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.deleteSoft(_selected!['MUSTERI_ID'] as int);
      _clear(); await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müşteri silindi (soft)')));
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
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad/Soyad/E-Mail/TC ara', border: OutlineInputBorder()),
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
                    tileColor: (_selected?['MUSTERI_ID'] == m['MUSTERI_ID']) ? Colors.indigo.withOpacity(.08) : null,
                    leading: const Icon(Icons.person),
                    title: Text('${m['AD'] ?? ''} ${m['SOYAD'] ?? ''}'),
                    subtitle: Text('TC: ${m['TC_NO'] ?? ''} • Tel: ${m['TELEFON'] ?? ''} • ${m['E-MAIL'] ?? ''} • ${m['DURUM'] ?? ''}'),
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
          Text(_selected == null ? 'Müşteri Ekle' : 'Müşteri Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: fTc, decoration: const InputDecoration(labelText: 'TC', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fEhliyet, decoration: const InputDecoration(labelText: 'Ehliyet No', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fAd, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fSoyad, decoration: const InputDecoration(labelText: 'Soyad', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fTel, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fEmail, decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fAdres, maxLines: 2, decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: fDurum, decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            if (_selected == null)
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Ekle'))
            else ...[
              FilledButton.icon(onPressed: _update, icon: const Icon(Icons.save), label: const Text('Güncelle')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete), label: const Text('Sil (Soft)')),
              const SizedBox(width: 8),
              TextButton(onPressed: _clear, child: const Text('Yeni')),
            ],
          ]),
        ]),
      )),
    ]);
  }
}