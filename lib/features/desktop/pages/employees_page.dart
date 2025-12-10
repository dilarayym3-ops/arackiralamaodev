import 'package:flutter/material.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../models/session.dart';

class EmployeesPage extends StatefulWidget { const EmployeesPage({super.key}); @override State<EmployeesPage> createState() => _EmployeesPageState(); }
class _EmployeesPageState extends State<EmployeesPage> {
  final _repo = EmployeeRepository();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final fTc = TextEditingController();
  final fEmail = TextEditingController();
  final fAd = TextEditingController();
  final fSoyad = TextEditingController();
  final fTel = TextEditingController();
  final fPoz = TextEditingController();
  final fDurum = TextEditingController(text: 'Aktif');

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try { _items = await _repo.listBySube(Session().current!.subeId, q: _q.text.trim().isEmpty ? null : _q.text.trim()); }
    catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fTc.text = m['TC_NO'] ?? '';
    fEmail.text = m['E-MAIL'] ?? '';
    fAd.text = m['AD'] ?? '';
    fSoyad.text = m['SOYAD'] ?? '';
    fTel.text = m['TELEFON'] ?? '';
    fPoz.text = m['POZISYON'] ?? '';
    fDurum.text = m['DURUM'] ?? 'Aktif';
  }

  Future<void> _create() async {
    try {
      await _repo.create(
        subeId: Session().current!.subeId,
        tc: fTc.text.trim(),
        email: fEmail.text.trim(),
        ad: fAd.text.trim(),
        soyad: fSoyad.text.trim(),
        telefon: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        pozisyon: fPoz.text.trim().isEmpty ? null : fPoz.text.trim(),
        durum: fDurum.text.trim().isEmpty ? 'Aktif' : fDurum.text.trim(),
      );
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan eklendi')));
    } catch (e) { _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        calisanId: _selected!['CALISAN_ID'] as int,
        telefon: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        pozisyon: fPoz.text.trim().isEmpty ? null : fPoz.text.trim(),
        durum: fDurum.text.trim().isEmpty ? 'Aktif' : fDurum.text.trim(),
        email: fEmail.text.trim().isEmpty ? null : fEmail.text.trim(),
      );
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan güncellendi')));
    } catch (e) { _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['CALISAN_ID'] as int);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan silindi')));
    } catch (e) { _err(e); }
  }

  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad/soyad/email/TC ara', border: OutlineInputBorder()), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Ara')),
          const SizedBox(width: 8), OutlinedButton(onPressed: () { _q.clear(); _load(); }, child: const Text('Temizle')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(padding: const EdgeInsets.all(12), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
            final m = _items[i];
            return ListTile(
              tileColor: (_selected?['CALISAN_ID'] == m['CALISAN_ID']) ? Colors.indigo.withOpacity(.08) : null,
              leading: const Icon(Icons.badge),
              title: Text('${m['AD'] ?? ''} ${m['SOYAD'] ?? ''}'),
              subtitle: Text('TC: ${m['TC_NO'] ?? ''} • ${m['E-MAIL'] ?? ''} • ${m['TELEFON'] ?? ''} • ${m['POZISYON'] ?? ''} • ${m['DURUM'] ?? ''}'),
              onTap: () => _fill(m),
            );
          })
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_selected == null ? 'Çalışan Ekle' : 'Çalışan Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: fTc, decoration: const InputDecoration(labelText: 'TC', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fEmail, decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fAd, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fSoyad, decoration: const InputDecoration(labelText: 'Soyad', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fTel, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fPoz, decoration: const InputDecoration(labelText: 'Pozisyon', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: fDurum, decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          if (_selected == null)
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Ekle'))
          else ...[
            FilledButton.icon(onPressed: _update, icon: const Icon(Icons.save), label: const Text('Güncelle')),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete), label: const Text('Sil')),
          ],
        ]),
      ]))),
    ]);
  }
}