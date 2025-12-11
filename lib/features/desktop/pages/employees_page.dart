import 'package:flutter/material.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/logs_repository.dart';
import '../../../models/session.dart';
import '../../../services/password_service.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});
  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _repo = EmployeeRepository();
  final _logs = LogsRepository();
  final _q = TextEditingController();
  
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;
  
  // Şifre koruması
  bool _isUnlocked = false;
  final _passwordController = TextEditingController();
  String? _passwordError;

  final fTc = TextEditingController();
  final fEmail = TextEditingController();
  final fAd = TextEditingController();
  final fSoyad = TextEditingController();
  final fTel = TextEditingController();
  final fPoz = TextEditingController();
  final fDurum = TextEditingController(text: 'Aktif');

  // Filtreler
  String _filterDurum = 'Tümü';
  String _filterPozisyon = 'Tümü';
  List<String> _pozisyonlar = ['Tümü'];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _passwordError = 'Şifre giriniz');
      return;
    }
    final isValid = await PasswordService.verifyPassword2(_passwordController.text.trim());
    if (isValid) {
      setState(() {
        _isUnlocked = true;
        _passwordError = null;
      });
      _load();
    } else {
      setState(() => _passwordError = 'Yönetici şifresi yanlış');
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      _items = await _repo.listBySube(Session().current!.subeId, q: _q.text.trim().isEmpty ? null : _q.text.trim());
      
      // Pozisyonları topla
      final pozSet = <String>{'Tümü'};
      for (final m in _items) {
        final poz = (m['POZISYON'] ?? '').toString();
        if (poz.isNotEmpty) pozSet.add(poz);
      }
      _pozisyonlar = pozSet.toList()..sort();
      
      _applyFilters();
    } catch (e) { _error = e.toString(); } 
    finally { setState(() => _loading = false); }
  }

  void _applyFilters() {
    // Filtreleme mantığı: getter _filteredItems üzerinden uygulanıyor, burada ekstra işlem yok.
    setState(() {});
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((m) {
      if (_filterDurum != 'Tümü') {
        final durum = (m['DURUM'] ?? '').toString();
        if (durum != _filterDurum) return false;
      }
      if (_filterPozisyon != 'Tümü') {
        final poz = (m['POZISYON'] ?? '').toString();
        if (poz != _filterPozisyon) return false;
      }
      return true;
    }).toList();
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

  void _clear() {
    setState(() => _selected = null);
    fTc.clear(); fEmail.clear(); fAd.clear(); fSoyad.clear(); 
    fTel.clear(); fPoz.clear(); fDurum.text = 'Aktif';
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
      
      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Çalışan',
        message: 'Çalışan eklendi: ${fAd.text} ${fSoyad.text}',
        details: {'tc': fTc.text, 'email': fEmail.text, 'pozisyon': fPoz.text},
        relatedType: 'CALISAN',
      );
      
      _clear();
      await _load();
      _sn('Çalışan eklendi');
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
      
      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Çalışan',
        message: 'Çalışan güncellendi: ${fAd.text} ${fSoyad.text}',
        details: {'calisanId': _selected!['CALISAN_ID']},
        relatedType: 'CALISAN',
        relatedId: _selected!['CALISAN_ID'] as int,
      );
      
      await _load();
      _sn('Çalışan güncellendi');
    } catch (e) { _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['CALISAN_ID'] as int);
      
      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Çalışan',
        message: 'Çalışan silindi/pasife alındı',
        details: {'calisanId': _selected!['CALISAN_ID']},
        relatedType: 'CALISAN',
        relatedId: _selected!['CALISAN_ID'] as int,
      );
      
      _clear();
      await _load();
      _sn('Çalışan silindi');
    } catch (e) { _err(e); }
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildPasswordScreen();
    }
    
    final filtered = _filteredItems;
    
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(
            controller: _q, 
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ad/soyad/email/TC ara', border: OutlineInputBorder()), 
            onSubmitted: (_) => _load()
          )),
          const SizedBox(width: 8), 
          FilledButton(onPressed: _load, child: const Text('Ara')),
          const SizedBox(width: 8), 
          OutlinedButton(onPressed: () { _q.clear(); _load(); }, child: const Text('Temizle')),
        ])),
        // Filtreler
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Text('Filtreler: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _filterDurum,
              items: ['Tümü', 'Aktif', 'Pasif'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() => _filterDurum = v ?? 'Tümü');
              },
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _pozisyonlar.contains(_filterPozisyon) ? _filterPozisyon : 'Tümü',
              items: _pozisyonlar.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() => _filterPozisyon = v ?? 'Tümü');
              },
            ),
            const Spacer(),
            Text('${filtered.length} / ${_items.length} kayıt', style: const TextStyle(color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Hata: $_error'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final durum = (m['DURUM'] ?? 'Aktif').toString();
                        final durumColor = durum == 'Aktif' ? Colors.green : Colors.orange;
                        return Card(child: ListTile(
                          leading: Icon(Icons.badge, color: durumColor),
                          title: Text('${m['AD'] ?? ''} ${m['SOYAD'] ?? ''}'),
                          subtitle: Text('TC: ${m['TC_NO'] ?? ''} • ${m['E-MAIL'] ?? ''} • ${m['TELEFON'] ?? ''} • ${m['POZISYON'] ?? ''}'),
                          trailing: Chip(
                            label: Text(durum),
                            backgroundColor: durumColor.withOpacity(0.1),
                            labelStyle: TextStyle(color: durumColor),
                          ),
                          onTap: () => _fill(m),
                        ));
                      }),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          DropdownButtonFormField<String>(
            value: fDurum.text.isEmpty ? 'Aktif' : fDurum.text,
            items: ['Aktif', 'Pasif'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => fDurum.text = v ?? 'Aktif',
            decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (_selected == null)
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Ekle'))
            else ...[
              FilledButton.icon(onPressed: _update, icon: const Icon(Icons.save), label: const Text('Güncelle')),
              OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete), label: const Text('Sil')),
              TextButton(onPressed: _clear, child: const Text('Yeni')),
            ],
          ]),
        ]),
      )),
    ]);
  }

  Widget _buildPasswordScreen() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: Colors.indigo),
                const SizedBox(height: 16),
                Text('Yönetici Girişi', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Çalışanlar sayfasına erişmek için yönetici şifresi gereklidir.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yönetici Şifresi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _verifyPassword(),
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 8),
                  Text(_passwordError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _verifyPassword,
                    child: const Text('Giriş'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}