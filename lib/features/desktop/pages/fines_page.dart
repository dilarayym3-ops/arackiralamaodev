import 'package:flutter/material.dart';

import '../../../data/repositories/fine_repository.dart';
import '../../../data/repositories/rental_repository.dart' as rent;
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';
import '../../../widgets/payment_type_dialog.dart';
import '../../../models/ui_router.dart';

class FinesPage extends StatefulWidget {
  const FinesPage({super.key});
  @override
  State<FinesPage> createState() => _FinesPageState();
}

class _FinesPageState extends State<FinesPage> {
  final _fineRepo = FineRepository();
  final _rentalRepo = rent.RentalRepository();
  final _payRepo = pay.PaymentRepository();

  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String?  _error;

  // Filtreler
  String _filterPayStatus = 'Tümü'; // Tümü, Ödendi, Kısmi, Ödenmedi
  String _filterCezaTuru = 'Tümü';
  List<String> _cezaTurleri = ['Tümü'];

  final fTarih = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  final fTur = TextEditingController();
  final fTutar = TextEditingController();
  Map<String, dynamic>? selRental;

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
      _items = await _fineRepo. listByBranch(Session().current! .subeId, q: _q.text. trim());
      
      // Ceza türlerini topla
      final turler = <String>{'Tümü'};
      for (final m in _items) {
        final tur = (m['CEZA_TURU'] ??  '').toString();
        if (tur. isNotEmpty) turler.add(tur);
      }
      _cezaTurleri = turler. toList()..sort();
      
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filteredItems = _items.where((m) {
      // Ödeme durumu filtresi
      final payStatus = (m['PAY_STATUS'] ?? 'Yok') as String;
      if (_filterPayStatus != 'Tümü') {
        if (_filterPayStatus == 'Ödendi' && payStatus != 'Ödendi') return false;
        if (_filterPayStatus == 'Kısmi' && payStatus != 'Kısmi') return false;
        if (_filterPayStatus == 'Ödenmedi' && payStatus != 'Yok') return false;
      }
      
      // Ceza türü filtresi
      if (_filterCezaTuru != 'Tümü') {
        final tur = (m['CEZA_TURU'] ?? '').toString();
        if (tur != _filterCezaTuru) return false;
      }
      
      return true;
    }).toList();
    setState(() {});
  }

  Future<Map<String, dynamic>?> _pickRental() => SearchSelectDialog. show(
        context,
        title: 'Kiralama Seç',
        loader: (q) async => await _rentalRepo.search(q:  q),
        itemTitle: (m) => 'Kir#${m['KIRALAMA_ID']} • ${m['PLAKA']} • ${m['Marka']} ${m['Model']}',
        itemSubtitle: (m) => 'Alış: ${m['ALIS_TARIHI']} • Plan Teslim: ${m['PLANLANAN_TESLIM_TARIHI']}',
      );

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    selRental = {'KIRALAMA_ID': m['KIRALAMA_ID']};
    fTarih.text = (m['CEZA_TARIHI'] ?? '').toString().substring(0, 10);
    fTur.text = (m['CEZA_TURU'] ?? '').toString();
    fTutar.text = (m['CEZA_TUTAR'] ?? '').toString();
    setState(() {});
  }

  Future<void> _add() async {
    final kid = selRental? ['KIRALAMA_ID'] as int? ;
    if (kid == null) {
      _sn('Kiralama seçiniz');
      return;
    }
    final tutar = double.tryParse(fTutar.text);
    final tarih = DateTime.tryParse(fTarih. text);
    final tur = fTur.text.trim().isEmpty ? '-' : fTur.text. trim();
    try {
      await _fineRepo.add(kiralamaId: kid, tarih: tarih ??  DateTime.now(), tur: tur, tutar: tutar ??  0);
      await _load();
      _sn('Ceza eklendi');
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _fineRepo.delete(_selected!['CEZA_ID'] as int);
      await _load();
      _sn('Ceza silindi');
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _quickPay() async {
    if (_selected == null) {
      _sn('Önce ceza satırı seçin');
      return;
    }
    
    final cezaId = _selected!['CEZA_ID'] as int;
    final cezaTutar = ((_selected!['CEZA_TUTAR'] as num?) ?? 0).toDouble();
    final paidTotal = ((_selected!['PAID_TOTAL'] as num?) ?? 0).toDouble();
    final kalan = cezaTutar - paidTotal;
    
    if (kalan <= 0) {
      _sn('Bu ceza zaten tamamen ödenmiş');
      return;
    }
    
    // Ödeme tipi seç
    final paymentType = await PaymentTypeDialog.show(
      context: context,
      title: 'Ödeme Tipi Seçin',
      message: 'Kalan tutar: ${kalan.toStringAsFixed(2)} TL',
    );
    
    if (paymentType == null) return; // İptal edildi
    
    // Kalan tutarı ödeme olarak ekle
    try {
      await _payRepo.add(cezaId: cezaId, tutar: kalan, tur: 'Ceza', tipi: paymentType);
      await _load();
      _sn('Ceza için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
    } catch (e) {
      _err(e);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ödendi':
        return const Color(0xFF4CAF50); // Yeşil
      case 'Kısmi':
        return const Color(0xFFFF9800); // Turuncu
      default:
        return const Color(0xFFF44336); // Kırmızı
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Ödendi':
        return Icons. check_circle;
      case 'Kısmi':
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
            // Arama ve Yenile
            Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _q,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ceza/Kiralama/Plaka ara... '),
                          onSubmitted: (_) => _load())),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _load, child: const Text('Yenile')),
                ])),
            
            // Filtreler
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Text('Filtreler:  ', style: TextStyle(fontWeight:  FontWeight.bold)),
                const SizedBox(width: 8),
                
                // Ödeme Durumu Filtresi
                DropdownButton<String>(
                  value: _filterPayStatus,
                  items: ['Tümü', 'Ödendi', 'Kısmi', 'Ödenmedi']. map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() => _filterPayStatus = v ??  'Tümü');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 16),
                
                // Ceza Türü Filtresi
                DropdownButton<String>(
                  value: _cezaTurleri.contains(_filterCezaTuru) ? _filterCezaTuru : 'Tümü',
                  items: _cezaTurleri.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() => _filterCezaTuru = v ?? 'Tümü');
                    _applyFilters();
                  },
                ),
                
                const Spacer(),
                Text('${_filteredItems.length} / ${_items.length} kayıt', style: const TextStyle(color: Colors.grey)),
              ]),
            ),
            const SizedBox(height: 8),
            
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
                            final payStatus = (m['PAY_STATUS'] ?? 'Yok') as String;
                            final paidTotal = (m['PAID_TOTAL'] as num?)?.toDouble() ?? 0;
                            final cezaTutar = (m['CEZA_TUTAR'] as num?)?.toDouble() ?? 0;
                            final kalan = cezaTutar - paidTotal;
                            final statusColor = _getStatusColor(payStatus);
                            
                            return Card(
                                child: ListTile(
                              leading: Icon(_getStatusIcon(payStatus), color: statusColor, size: 32),
                              title: Text('Ceza#${m['CEZA_ID']} • Kir#${m['KIRALAMA_ID']} • ${m['PLAKA']} • ${m['Marka']} ${m['Model']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tarih: ${m['CEZA_TARIHI']} • Tür: ${m['CEZA_TURU']} • Tutar: ${cezaTutar.toStringAsFixed(2)} TL'),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        payStatus == 'Yok' ? 'ÖDENMEDİ' : payStatus. toUpperCase(),
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Ödenen: ${paidTotal.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
                                    if (kalan > 0) ...[
                                      const SizedBox(width: 8),
                                      Text('Kalan: ${kalan.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 12, color: Colors.red. shade700, fontWeight: FontWeight.bold)),
                                    ],
                                  ]),
                                ],
                              ),
                              trailing:  Wrap(spacing: 6, children: [
                                OutlinedButton. icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit, size: 18), label: const Text('Seç')),
                                if (kalan > 0)
                                  FilledButton.icon(
                                      onPressed: () {
                                        _fill(m);
                                        _quickPay();
                                      },
                                      icon: const Icon(Icons.payments, size: 18),
                                      label: const Text('Öde')),
                                OutlinedButton.icon(
                                    onPressed: () {
                                      _fill(m);
                                      _delete();
                                    },
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Sil')),
                              ]),
                              onTap: () => _fill(m),
                            ));
                          },
                        ),
            ),
          ])),
      const VerticalDivider(width: 1),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ceza Ekle', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () async {
                      final r = await _pickRental();
                      if (r != null) setState(() => selRental = r);
                    },
                    icon: const Icon(Icons.key),
                    label: Text(selRental == null ? 'Kiralama Seç' : 'Kir#${selRental!['KIRALAMA_ID']}')),
                const SizedBox(height: 8),
                TextField(controller: fTarih, decoration:  const InputDecoration(labelText: 'Ceza Tarihi (YYYY-MM-DD)')),
                const SizedBox(height: 8),
                TextField(controller: fTur, decoration: const InputDecoration(labelText: 'Ceza Türü')),
                const SizedBox(height: 8),
                TextField(controller: fTutar, decoration: const InputDecoration(labelText: 'Ceza Tutarı (TL)'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(children: [
                  FilledButton. icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Ekle')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _selected == null ? null : _quickPay, icon: const Icon(Icons.payments), label: const Text('Seçiliyi Öde')),
                ]),
                
                // Seçili ceza detayı
                if (_selected != null) ...[
                  const Divider(height: 32),
                  Text('Seçili Ceza Detayı', style: Theme. of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDetailRow('Ceza ID', '${_selected!['CEZA_ID']}'),
                  _buildDetailRow('Kiralama ID', '${_selected! ['KIRALAMA_ID']}'),
                  _buildDetailRow('Plaka', '${_selected!['PLAKA']}'),
                  _buildDetailRow('Tarih', '${_selected!['CEZA_TARIHI']}'),
                  _buildDetailRow('Tür', '${_selected!['CEZA_TURU']}'),
                  _buildDetailRow('Tutar', '${((_selected!['CEZA_TUTAR'] as num?) ?? 0).toStringAsFixed(2)} TL'),
                  _buildDetailRow('Ödenen', '${((_selected!['PAID_TOTAL'] as num?) ?? 0).toStringAsFixed(2)} TL'),
                  _buildDetailRow('Kalan', '${(((_selected!['CEZA_TUTAR'] as num?) ?? 0) - ((_selected!['PAID_TOTAL'] as num?) ?? 0)).toStringAsFixed(2)} TL'),
                  _buildDetailRow('Durum', '${_selected!['PAY_STATUS'] ?? 'Yok'}'),
                ],
              ]))),
    ]);
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}