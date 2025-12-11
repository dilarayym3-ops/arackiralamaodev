import 'package:flutter/material.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/logs_repository.dart';
import '../../../models/session.dart';
import '../../../services/password_service.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _repo = CustomerRepository();
  final _logs = LogsRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  bool _authorized = false;
  String?  _error;

  // Filtreler
  String _filterDurum = 'Tümü';

  // Form
  final fTc = TextEditingController();
  final fEhliyet = TextEditingController();
  final fAd = TextEditingController();
  final fSoyad = TextEditingController();
  final fTel = TextEditingController();
  final fEmail = TextEditingController();
  final fAdres = TextEditingController();
  final fDurum = TextEditingController(text: 'Aktif');

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final ok = await PasswordService.showPasswordDialog(context, passwordLevel: 2, title: 'Müşteriler - Yönetici Şifresi');
    if (ok) {
      setState(() => _authorized = true);
      _load();
    } else {
      setState(() => _authorized = false);
    }
  }

  Future<void> _load() async {
    if (! _authorized) return;
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      _items = await _repo.listAll(q: _q.text.trim().isEmpty ? null : _q.text.trim());
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filteredItems = _items.where((m) {
      if (_filterDurum != 'Tümü') {
        final durum = (m['DURUM'] ??  'Aktif').toString();
        if (durum != _filterDurum) return false;
      }
      return true;
    }).toList();
    setState(() {});
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fTc.text = m['TC_NO'] ?? '';
    fEhliyet.text = m['EHLIYET_ID'] ?? '';
    fAd.text = m['AD'] ??  '';
    fSoyad. text = m['SOYAD'] ?? '';
    fTel.text = m['TELEFON'] ?? '';
    fEmail.text = m['E-MAIL'] ?? '';
    fAdres.text = m['ADRES'] ?? '';
    fDurum.text = m['DURUM'] ?? 'Aktif';
  }

  void _clear() {
    setState(() => _selected = null);
    fTc.clear();
    fEhliyet.clear();
    fAd.clear();
    fSoyad.clear();
    fTel.clear();
    fEmail.clear();
    fAdres.clear();
    fDurum.text = 'Aktif';
  }

  Future<void> _create() async {
    if (fTc.text.trim().isEmpty || fAd.text.trim().isEmpty || fSoyad.text.trim().isEmpty) {
      _showError('TC, Ad ve Soyad zorunludur');
      return;
    }
    try {
      await _repo.create(
        tc: fTc.text.trim(),
        ehliyet: fEhliyet.text.trim(),
        ad: fAd.text.trim(),
        soyad: fSoyad. text.trim(),
        tel: fTel.text.trim(),
        email: fEmail.text.trim(),
        adres: fAdres.text.trim().isEmpty ? null : fAdres. text.trim(),
      );
      await _logs.add(
        subeId: Session().current?. subeId ?? 0,
        calisanId: Session().current?.calisanId,
        action: 'Müşteri',
        message: 'Müşteri eklendi:  ${fAd.text} ${fSoyad.text}',
        details: {'tc': fTc.text, 'ad': fAd.text, 'soyad': fSoyad.text},
        relatedType: 'MUSTERI',
      );
      _clear();
      await _load();
      _showSuccess('Müşteri eklendi');
    } catch (e) {
      _showError('Hata: $e');
    }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        id: _selected! ['MUSTERI_ID'] as int,
        tel: fTel.text.trim().isEmpty ? null : fTel. text.trim(),
        email: fEmail.text.trim().isEmpty ? null : fEmail.text. trim(),
        adres: fAdres.text.trim().isEmpty ? null : fAdres.text.trim(),
        durum: fDurum.text.trim().isEmpty ? null : fDurum.text. trim(),
      );
      await _logs.add(
        subeId: Session().current?.subeId ?? 0,
        calisanId: Session().current?.calisanId,
        action: 'Müşteri',
        message: 'Müşteri güncellendi:  ${fAd.text} ${fSoyad.text}',
        details: {'musteriId': _selected!['MUSTERI_ID']},
        relatedType: 'MUSTERI',
        relatedId: _selected!['MUSTERI_ID'] as int,
      );
      await _load();
      _showSuccess('Müşteri güncellendi');
    } catch (e) {
      _showError('Hata: $e');
    }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.deleteSoft(_selected!['MUSTERI_ID'] as int);
      await _logs.add(
        subeId: Session().current?.subeId ?? 0,
        calisanId: Session().current?.calisanId,
        action: 'Müşteri',
        message: 'Müşteri silindi (soft)',
        details: {'musteriId': _selected!['MUSTERI_ID']},
        relatedType: 'MUSTERI',
        relatedId: _selected!['MUSTERI_ID'] as int,
      );
      _clear();
      await _load();
      _showSuccess('Müşteri silindi');
    } catch (e) {
      _showError('Hata: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    if (! _authorized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height:  16),
            const Text('Bu sayfaya erişim için yönetici şifresi gereklidir. '),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _checkAuth,
              icon: const Icon(Icons.lock_open),
              label: const Text('Şifre Gir'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Sol Panel - Liste
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Arama ve Filtreler
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _q,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:  'Ad/Soyad/TC/E-Mail ara...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _load, child: const Text('Ara')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            _q.clear();
                            _load();
                          },
                          child: const Text('Temizle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Durum:  ', style: TextStyle(fontWeight:  FontWeight.bold)),
                        DropdownButton<String>(
                          value: _filterDurum,
                          items: ['Tümü', 'Aktif', 'Pasif', 'Silindi']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _filterDurum = v ??  'Tümü');
                            _applyFilters();
                          },
                        ),
                        const Spacer(),
                        Text(
                          '${_filteredItems.length} / ${_items.length} müşteri',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Liste
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Hata: $_error'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredItems.length,
                            separatorBuilder:  (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final m = _filteredItems[i];
                              final durum = (m['DURUM'] ?? 'Aktif').toString();
                              final durumColor = durum == 'Aktif'
                                  ? Colors.green
                                  : durum == 'Pasif'
                                      ? Colors.orange
                                      : Colors.red;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: durumColor. withOpacity(0.1),
                                    child: Icon(Icons.person, color: durumColor),
                                  ),
                                  title: Text('${m['AD'] ?? ''} ${m['SOYAD'] ?? ''}'),
                                  subtitle:  Text(
                                    'TC: ${m['TC_NO'] ?? ''} • Tel: ${m['TELEFON'] ?? ''}\n'
                                    'E-Mail: ${m['E-MAIL'] ?? ''}',
                                  ),
                                  trailing:  Chip(
                                    label: Text(durum, style: TextStyle(color: durumColor, fontSize: 11)),
                                    backgroundColor: durumColor.withOpacity(0.1),
                                  ),
                                  isThreeLine: true,
                                  onTap: () => _fill(m),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Sağ Panel - Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selected == null ? 'Müşteri Ekle' : 'Müşteri Düzenle',
                  style:  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fTc,
                  decoration: const InputDecoration(labelText: 'TC Kimlik No *', border: OutlineInputBorder()),
                  maxLength: 11,
                  enabled: _selected == null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fEhliyet,
                  decoration: const InputDecoration(labelText: 'Ehliyet No *', border: OutlineInputBorder()),
                  enabled: _selected == null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fAd,
                        decoration: const InputDecoration(labelText: 'Ad *', border: OutlineInputBorder()),
                        enabled: _selected == null,
                      ),
                    ),
                    const SizedBox(width:  8),
                    Expanded(
                      child: TextField(
                        controller: fSoyad,
                        decoration: const InputDecoration(labelText: 'Soyad *', border: OutlineInputBorder()),
                        enabled: _selected == null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fTel,
                  decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fEmail,
                  decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller:  fAdres,
                  decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: ['Aktif', 'Pasif', 'Silindi'].contains(fDurum.text) ? fDurum.text :  'Aktif',
                  items: ['Aktif', 'Pasif', 'Silindi']
                      .map((e) => DropdownMenuItem(value:  e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => fDurum.text = v ?? 'Aktif'),
                  decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing:  8,
                  children:  [
                    if (_selected == null)
                      FilledButton. icon(
                        onPressed:  _create,
                        icon:  const Icon(Icons.add),
                        label: const Text('Ekle'),
                      )
                    else ...[
                      FilledButton. icon(
                        onPressed:  _update,
                        icon:  const Icon(Icons.save),
                        label: const Text('Güncelle'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete),
                        label: const Text('Sil'),
                      ),
                      TextButton(onPressed: _clear, child: const Text('Yeni Müşteri')),
                    ],
                  ],
                ),
                if (_selected != null) ...[
                  const Divider(height: 32),
                  Text('Müşteri Detayları', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDetailRow('Müşteri ID', '${_selected!['MUSTERI_ID']}'),
                  _buildDetailRow('TC', '${_selected!['TC_NO'] ?? '-'}'),
                  _buildDetailRow('Ehliyet', '${_selected!['EHLIYET_ID'] ?? '-'}'),
                  _buildDetailRow('Ad Soyad', '${_selected!['AD'] ?? ''} ${_selected!['SOYAD'] ?? ''}'),
                  _buildDetailRow('Telefon', '${_selected! ['TELEFON'] ?? '-'}'),
                  _buildDetailRow('E-Mail', '${_selected!['E-MAIL'] ?? '-'}'),
                  _buildDetailRow('Adres', '${_selected!['ADRES'] ?? '-'}'),
                  _buildDetailRow('Kayıt Tarihi', '${_selected!['KAYIT_TARIHI'] ?? '-'}'),
                  _buildDetailRow('Durum', '${_selected!['DURUM'] ?? 'Aktif'}'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}