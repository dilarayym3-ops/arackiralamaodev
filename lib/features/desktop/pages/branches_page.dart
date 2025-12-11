import 'package:flutter/material.dart';
import '../../../data/repositories/sube_repository.dart';
import '../../../data/repositories/logs_repository.dart';
import '../../../models/session.dart';
import '../../../services/password_service.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});
  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  final _repo = SubeRepository();
  final _logs = LogsRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  // Şifre koruması
  bool _isUnlocked = false;
  final _passwordController = TextEditingController();
  String? _passwordError;

  // Filtreler
  String _filterIl = 'Tümü';
  List<String> _iller = ['Tümü'];

  final fAdi = TextEditingController();
  final fAdres = TextEditingController();
  final fTel = TextEditingController();
  final fIl = TextEditingController();
  final fIlce = TextEditingController();

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
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      final all = await _repo.getAll();
      final term = _q.text.trim().toLowerCase();
      _items = term.isEmpty
          ? all
          : all.where((e) =>
              (e['SUBE_ADI'] ?? '').toString().toLowerCase().contains(term) ||
              (e['IL'] ?? '').toString().toLowerCase().contains(term) ||
              (e['ILCE'] ?? '').toString().toLowerCase().contains(term),
            ).toList();

      // İlleri topla
      final ilSet = <String>{'Tümü'};
      for (final m in _items) {
        final il = (m['IL'] ?? '').toString();
        if (il.isNotEmpty) ilSet.add(il);
      }
      _iller = ilSet.toList()..sort();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((m) {
      if (_filterIl != 'Tümü') {
        final il = (m['IL'] ?? '').toString();
        if (il != _filterIl) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _fill(Map<String, dynamic> m) async {
    setState(() => _selected = m);
    fAdi.text = m['SUBE_ADI'] ?? '';
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

  void _clear() {
    setState(() => _selected = null);
    fAdi.clear();
    fAdres.clear();
    fTel.clear();
    fIl.clear();
    fIlce.clear();
  }

  Future<void> _create() async {
    try {
      await _repo.create(
        subeAdi: fAdi.text.trim(),
        adres: fAdres.text.trim(),
        telefon: fTel.text.trim().isEmpty ? null : fTel.text.trim(),
        il: fIl.text.trim(),
        ilce: fIlce.text.trim(),
      );

      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Şube',
        message: 'Şube eklendi: ${fAdi.text}',
        details: {'subeAdi': fAdi.text, 'il': fIl.text, 'ilce': fIlce.text},
        relatedType: 'SUBE',
      );

      _clear();
      await _load();
      _sn('Şube eklendi');
    } catch (e) {
      _err(e);
    }
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

      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Şube',
        message: 'Şube güncellendi: ${fAdi.text}',
        details: {'subeId': _selected!['SUBE_ID']},
        relatedType: 'SUBE',
        relatedId: _selected!['SUBE_ID'] as int,
      );

      await _load();
      _sn('Şube güncellendi');
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['SUBE_ID'] as int);

      await _logs.add(
        subeId: Session().current!.subeId,
        calisanId: Session().current!.calisanId,
        action: 'Şube',
        message: 'Şube silindi',
        details: {'subeId': _selected!['SUBE_ID']},
        relatedType: 'SUBE',
        relatedId: _selected!['SUBE_ID'] as int,
      );

      _clear();
      await _load();
      _sn('Şube silindi');
    } catch (e) {
      _err(e);
    }
  }

  void _sn(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildPasswordScreen();
    }

    final filtered = _filteredItems;

    return Row(children: [
      Expanded(
        flex: 2,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Şube/İl/İlçe ara',
                        border: OutlineInputBorder()),
                    onSubmitted: (_) => _load()),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _load, child: const Text('Ara')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () {
                    _q.clear();
                    _load();
                  },
                  child: const Text('Temizle')),
            ]),
          ),
          // Filtreler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Text('İl: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _iller.contains(_filterIl) ? _filterIl : 'Tümü',
                items: _iller
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filterIl = v ?? 'Tümü');
                },
              ),
              const Spacer(),
              Text('${filtered.length} / ${_items.length} kayıt',
                  style: const TextStyle(color: Colors.grey)),
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
                          return Card(
                              child: ListTile(
                            tileColor: (_selected?['SUBE_ID'] == m['SUBE_ID'])
                                ? Colors.indigo.withOpacity(0.08) // DÜZELTİLDİ
                                : null,
                            leading: const Icon(Icons.home_work),
                            title: Text(m['SUBE_ADI'] ?? ''),
                            subtitle:
                                Text('${m['IL'] ?? ''} / ${m['ILCE'] ?? ''}'),
                            onTap: () => _fill(m),
                          ));
                        },
                      ),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      Expanded(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selected == null ? 'Şube Ekle' : 'Şube Düzenle',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                  controller: fAdi,
                  decoration: const InputDecoration(
                      labelText: 'Şube Adı', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                  controller: fAdres,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Adres', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                  controller: fTel,
                  decoration: const InputDecoration(
                      labelText: 'Telefon', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                  controller: fIl,
                  decoration: const InputDecoration(
                      labelText: 'İl', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                  controller: fIlce,
                  decoration: const InputDecoration(
                      labelText: 'İlçe', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (_selected == null)
                  FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Ekle'))
                else ...[
                  FilledButton.icon(
                      onPressed: _update,
                      icon: const Icon(Icons.save),
                      label: const Text('Güncelle')),
                  OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete),
                      label: const Text('Sil')),
                  TextButton(
                      onPressed: _clear, child: const Text('Yeni')),
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
                const Icon(Icons.admin_panel_settings,
                    size: 64, color: Colors.indigo),
                const SizedBox(height: 16),
                Text('Yönetici Girişi',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                    'Şubeler sayfasına erişmek için yönetici şifresi gereklidir.',
                    textAlign: TextAlign.center),
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
                  Text(_passwordError!,
                      style: const TextStyle(color: Colors.red)),
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