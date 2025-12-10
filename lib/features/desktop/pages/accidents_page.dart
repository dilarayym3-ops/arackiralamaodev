import 'package:flutter/material.dart';
import '../../../data/repositories/accident_repository.dart';
import '../../../data/repositories/rental_repository.dart' as rent;
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';

class AccidentsPage extends StatefulWidget {
  const AccidentsPage({super.key});
  @override
  State<AccidentsPage> createState() => _AccidentsPageState();
}

class _AccidentsPageState extends State<AccidentsPage> {
  final _repo = AccidentRepository();
  final _rentRepo = rent.RentalRepository();
  final _payRepo = pay.PaymentRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  String _filterPayStatus = 'Tumu';
  String _filterHasarTuru = 'Tumu';
  String _filterSigortaDurumu = 'Tumu';
  List<String> _hasarTurleri = ['Tumu'];
  List<String> _sigortaDurumlari = ['Tumu'];

  Map<String, dynamic>? selRental;
  final fTarih = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  final fHasarTur = TextEditingController();
  final fHasarMiktar = TextEditingController();
  final fSigortaDurum = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      _items = await _repo.listByBranch(Session().current!.subeId, q: _q.text.trim());

      final hasarSet = <String>{'Tumu'};
      final sigortaSet = <String>{'Tumu'};
      for (final m in _items) {
        final ht = (m['HASAR_TURU'] ??  '').toString();
        final sd = (m['SIGORTA_DURUMU'] ??  '').toString();
        if (ht. isNotEmpty) hasarSet.add(ht);
        if (sd.isNotEmpty) sigortaSet.add(sd);
      }
      _hasarTurleri = hasarSet. toList()..sort();
      _sigortaDurumlari = sigortaSet.toList()..sort();

      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filteredItems = _items.where((m) {
      final payStatus = (m['PAY_STATUS'] ?? 'Yok') as String;
      if (_filterPayStatus != 'Tumu') {
        if (_filterPayStatus == 'Odendi' && payStatus != 'Odendi') return false;
        if (_filterPayStatus == 'Kismi' && payStatus != 'Kismi') return false;
        if (_filterPayStatus == 'Odenmedi' && payStatus != 'Yok') return false;
      }

      if (_filterHasarTuru != 'Tumu') {
        final ht = (m['HASAR_TURU'] ?? '').toString();
        if (ht != _filterHasarTuru) return false;
      }

      if (_filterSigortaDurumu != 'Tumu') {
        final sd = (m['SIGORTA_DURUMU'] ?? '').toString();
        if (sd != _filterSigortaDurumu) return false;
      }

      return true;
    }).toList();
    setState(() {});
  }

  Future<Map<String, dynamic>?> _pickRental() => SearchSelectDialog.show(
        context,
        title: 'Kiralama Sec',
        loader: (q) async => await _rentRepo.search(q:  q),
        itemTitle: (m) => 'Kiralama #${m['KIRALAMA_ID']} - ${m['PLAKA']} - ${m['Marka']} ${m['Model']}',
        itemSubtitle: (m) => 'Alis: ${m['ALIS_TARIHI']} - Plan Teslim: ${m['PLANLANAN_TESLIM_TARIHI']}',
      );

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    selRental = {'KIRALAMA_ID': m['KIRALAMA_ID']};
    fTarih. text = (m['KAZA_TARIHI'] ?? '').toString().substring(0, 10);
    fHasarTur.text = (m['HASAR_TURU'] ?? '').toString();
    fHasarMiktar.text = (m['HASAR_MIKTARI'] ?? '').toString();
    fSigortaDurum.text = (m['SIGORTA_DURUMU'] ?? '').toString();
    setState(() {});
  }

  void _clear() {
    _selected = null;
    selRental = null;
    fTarih.text = DateTime.now().toString().substring(0, 10);
    fHasarTur.clear();
    fHasarMiktar.clear();
    fSigortaDurum.clear();
    setState(() {});
  }

  Future<void> _add() async {
    final kid = selRental? ['KIRALAMA_ID'] as int?;
    if (kid == null) {
      _sn('Kiralama seciniz');
      return;
    }
    final miktar = double.tryParse(fHasarMiktar.text);
    final tarih = DateTime.tryParse(fTarih. text);
    final hasarTur = fHasarTur. text.trim().isEmpty ? '-' : fHasarTur.text.trim();
    try {
      await _repo.add(
        kiralamaId: kid,
        tarih: tarih ??  DateTime.now(),
        hasarTuru: hasarTur,
        hasarMiktari: miktar,
        sigortaDurumu: fSigortaDurum.text.trim().isEmpty ? null : fSigortaDurum.text.trim(),
      );
      _clear();
      await _load();
      _sn('Kaza eklendi');
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['KAZA_ID'] as int);
      _clear();
      await _load();
      _sn('Kaza silindi');
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _quickPay() async {
    if (_selected == null) {
      _sn('Once kaza kaydi secin');
      return;
    }

    final kazaId = _selected!['KAZA_ID'] as int;
    final hasarMiktari = ((_selected!['HASAR_MIKTARI'] as num?) ?? 0).toDouble();
    final paidTotal = ((_selected!['PAID_TOTAL'] as num?) ?? 0).toDouble();
    final kalan = hasarMiktari - paidTotal;

    if (hasarMiktari <= 0) {
      _sn('Hasar miktari 0 veya belirtilmemis');
      return;
    }

    if (kalan <= 0) {
      _sn('Bu kaza zaten tamamen odenmis');
      return;
    }

    try {
      await _payRepo.add(kazaId:  kazaId, tutar: kalan, tur: 'Kaza', tipi: 'Nakit');
      await _load();
      _sn('Kaza icin ${kalan. toStringAsFixed(2)} TL odeme eklendi');
    } catch (e) {
      _err(e);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Odendi':
        return Colors.green;
      case 'Kismi':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Odendi':
        return Icons.check_circle;
      case 'Kismi':
        return Icons.hourglass_bottom;
      default:
        return Icons.cancel;
    }
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        flex: 2,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets. all(12),
            child: Row(children:  [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:  'Kaza/Kiralama/Plaka/Marka/Model ara.. .',
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _load, child: const Text('Yenile')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:  Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Filtreler:', style: TextStyle(fontWeight:  FontWeight.bold)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Odeme:  '),
                  DropdownButton<String>(
                    value: _filterPayStatus,
                    items: ['Tumu', 'Odendi', 'Kismi', 'Odenmedi'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      _filterPayStatus = v ??  'Tumu';
                      _applyFilters();
                    },
                  ),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Hasar:  '),
                  DropdownButton<String>(
                    value: _hasarTurleri.contains(_filterHasarTuru) ? _filterHasarTuru : 'Tumu',
                    items: _hasarTurleri.map((e) => DropdownMenuItem(value: e, child: Text(e. length > 15 ? '${e.substring(0, 15)}...' : e))).toList(),
                    onChanged:  (v) {
                      _filterHasarTuru = v ?? 'Tumu';
                      _applyFilters();
                    },
                  ),
                ]),
                Row(mainAxisSize: MainAxisSize. min, children: [
                  const Text('Sigorta:  '),
                  DropdownButton<String>(
                    value: _sigortaDurumlari.contains(_filterSigortaDurumu) ? _filterSigortaDurumu : 'Tumu',
                    items: _sigortaDurumlari.map((e) => DropdownMenuItem(value: e, child: Text(e.length > 15 ? '${e. substring(0, 15)}...' : e))).toList(),
                    onChanged: (v) {
                      _filterSigortaDurumu = v ??  'Tumu';
                      _applyFilters();
                    },
                  ),
                ]),
                Text('${_filteredItems.length} / ${_items.length} kayit', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Hata: $_error'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount:  _filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = _filteredItems[i];
                          final payStatus = (m['PAY_STATUS'] ?? 'Yok') as String;
                          final paidTotal = (m['PAID_TOTAL'] as num?)?.toDouble() ?? 0;
                          final hasarMiktari = (m['HASAR_MIKTARI'] as num?)?.toDouble() ?? 0;
                          final kalan = hasarMiktari - paidTotal;
                          final statusColor = _getStatusColor(payStatus);

                          return Card(
                            child: ListTile(
                              leading:  Icon(_getStatusIcon(payStatus), color: statusColor, size: 32),
                              title: Text('Kaza#${m['KAZA_ID']} - Kir#${m['KIRALAMA_ID']} - ${m['PLAKA']} - ${m['Marka']} ${m['Model']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tarih: ${m['KAZA_TARIHI']} - Hasar: ${m['HASAR_TURU'] ?? '-'} - Miktar: ${hasarMiktari.toStringAsFixed(2)} TL'),
                                  Text('Sigorta Durumu: ${m['SIGORTA_DURUMU'] ??  '-'}'),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical:  2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        payStatus == 'Yok' ? 'ODENMEDI' : payStatus. toUpperCase(),
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Odenen: ${paidTotal.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
                                    if (kalan > 0) ...[
                                      const SizedBox(width: 8),
                                      Text('Kalan: ${kalan.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 12, color: Colors.red. shade700, fontWeight: FontWeight.bold)),
                                    ],
                                  ]),
                                ],
                              ),
                              trailing:  Wrap(spacing: 6, children: [
                                OutlinedButton. icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit, size: 18), label: const Text('Sec')),
                                if (kalan > 0)
                                  FilledButton.icon(
                                    onPressed: () {
                                      _fill(m);
                                      _quickPay();
                                    },
                                    icon: const Icon(Icons.payments, size: 18),
                                    label: const Text('Ode'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _fill(m);
                                    _delete();
                                  },
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Sil'),
                                ),
                              ]),
                              onTap: () => _fill(m),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kaza Ekle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final r = await _pickRental();
                if (r != null) setState(() => selRental = r);
              },
              icon: const Icon(Icons.key),
              label: Text(selRental == null ? 'Kiralama Sec' : 'Kiralama#${selRental!['KIRALAMA_ID']}'),
            ),
            const SizedBox(height: 8),
            TextField(controller: fTarih, decoration:  const InputDecoration(labelText:  'Kaza Tarihi (YYYY-MM-DD)')),
            const SizedBox(height: 8),
            TextField(controller: fHasarTur, decoration: const InputDecoration(labelText: 'Hasar Turu')),
            const SizedBox(height: 8),
            TextField(controller:  fHasarMiktar, decoration: const InputDecoration(labelText: 'Hasar Miktari (TL)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: fSigortaDurum, decoration: const InputDecoration(labelText: 'Sigorta Durumu')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton. icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Ekle')),
              OutlinedButton.icon(onPressed: _selected == null ? null : _quickPay, icon: const Icon(Icons.payments), label: const Text('Seciliyi Ode')),
              TextButton.icon(onPressed: _clear, icon: const Icon(Icons.clear), label: const Text('Temizle')),
            ]),
            if (_selected != null) ...[
              const Divider(height: 32),
              Text('Secili Kaza Detayi', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildDetailRow('Kaza ID', '${_selected!['KAZA_ID']}'),
              _buildDetailRow('Kiralama ID', '${_selected!['KIRALAMA_ID']}'),
              _buildDetailRow('Plaka', '${_selected!['PLAKA']}'),
              _buildDetailRow('Tarih', '${_selected!['KAZA_TARIHI']}'),
              _buildDetailRow('Hasar Turu', '${_selected!['HASAR_TURU'] ?? '-'}'),
              _buildDetailRow('Hasar Miktari', '${((_selected!['HASAR_MIKTARI'] as num?) ?? 0).toStringAsFixed(2)} TL'),
              _buildDetailRow('Sigorta Durumu', '${_selected!['SIGORTA_DURUMU'] ?? '-'}'),
              _buildDetailRow('Odenen', '${((_selected!['PAID_TOTAL'] as num?) ?? 0).toStringAsFixed(2)} TL'),
              _buildDetailRow('Kalan', '${(((_selected!['HASAR_MIKTARI'] as num?) ?? 0) - ((_selected!['PAID_TOTAL'] as num?) ?? 0)).toStringAsFixed(2)} TL'),
              _buildDetailRow('Odeme Durumu', '${_selected!['PAY_STATUS'] ?? 'Yok'}'),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets. symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}