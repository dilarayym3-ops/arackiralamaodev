import 'package:flutter/material.dart';

import '../../../data/repositories/insurance_repository.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';
import '../../../widgets/payment_type_dialog.dart';
import '../../../models/ui_router.dart';

class InsurancesPage extends StatefulWidget { const InsurancesPage({super.key}); @override State<InsurancesPage> createState() => _InsurancesPageState(); }
class _InsurancesPageState extends State<InsurancesPage> {
  final _repo = InsuranceRepository();
  final _carRepo = CarRepository();
  final _payRepo = pay.PaymentRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? selArac;
  final fAd = TextEditingController();
  final fKapsam = TextEditingController();
  final fAciklama = TextEditingController();
  final fMaliyet = TextEditingController();
  final fBas = TextEditingController(text: DateTime.now().toString().substring(0,10));
  final fBit = TextEditingController();
  bool aktif = true;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _items = []; _selected = null; });
    try {
      _items = await _repo.listByBranch(Session().current!.subeId, q: _q.text.trim());
      for (final m in _items) {
        final id = m['SIGORTA_ID'] as int;
        final maliyet = (m['MALIYET'] as num?)?.toDouble() ?? 0.0;
        final paid = await _payRepo.totalByInsurance(id);
        m['PAID_TOTAL'] = paid;
        m['PAY_STATUS'] = paid >= maliyet && maliyet > 0 ? 'Ödendi' : (paid > 0 ? 'Kısmi' : 'Yok');
      }
    } catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    selArac = {'SASE_NO': m['SASE_NO'], 'PLAKA': m['PLAKA'], 'Marka': m['Marka'], 'Model': m['Model']};
    fAd.text = (m['SIGORTA_ADI'] ?? '').toString();
    fKapsam.text = (m['KAPSAM_TURU'] ?? '').toString();
    fAciklama.text = (m['KAPSAM_ACIKLAMASI'] ?? '').toString();
    fMaliyet.text = (m['MALIYET'] ?? '').toString();
    fBas.text = (m['BASLANGIC_TARIHI'] ?? '').toString().substring(0,10);
    fBit.text = (m['BITIS_TARIHI'] ?? '').toString().substring(0,10);
    aktif = ((m['AKTIFMI'] ?? 0) == 1);
    setState(() {});
  }

  Future<Map<String, dynamic>?> _pickArac() => SearchSelectDialog.show(
    context, title: 'Araç Seç',
    loader: (q) async => await _carRepo.listDetailedBySube(subeId: Session().current!.subeId, q: q, pageSize: 100),
    itemTitle: (m) => '${m['Marka']} ${m['Model']} (${m['Yil']}) • ${m['PLAKA']}',
    itemSubtitle: (m) => 'Şase: ${m['SASE_NO']}',
  );

  Future<void> _addOrSave({bool save = false}) async {
    final sase = (selArac?['SASE_NO'] ?? (_selected?['SASE_NO'] ?? '')) as String;
    if (sase.isEmpty) { _sn('Önce araç seçin'); return; }
    final maliyet = fMaliyet.text.trim().isEmpty ? null : double.tryParse(fMaliyet.text);
    final bas = DateTime.tryParse(fBas.text);
    final bit = fBit.text.trim().isEmpty ? null : DateTime.tryParse(fBit.text);
    try {
      if (save && _selected != null) {
        await _repo.update(
          sigortaId: _selected!['SIGORTA_ID'] as int,
          ad: fAd.text.trim().isEmpty ? null : fAd.text.trim(),
          kapsamTuru: fKapsam.text.trim().isEmpty ? null : fKapsam.text.trim(),
          kapsamAciklama: fAciklama.text.trim().isEmpty ? null : fAciklama.text.trim(),
          maliyet: maliyet,
          baslangic: bas,
          bitis: bit,
          aktif: aktif,
        );
        _sn('Sigorta kaydedildi');
      } else {
        await _repo.add(
          saseNo: sase,
          ad: fAd.text.trim().isEmpty ? null : fAd.text.trim(),
          kapsamTuru: fKapsam.text.trim().isEmpty ? null : fKapsam.text.trim(),
          kapsamAciklama: fAciklama.text.trim().isEmpty ? null : fAciklama.text.trim(),
          maliyet: maliyet,
          baslangic: bas,
          bitis: bit,
          aktif: aktif,
        );
        _sn('Sigorta eklendi');
      }
      await _load();
    } catch (e) { _err(e); }
  }

  Future<void> _quickPay() async {
    final sigId = _selected?['SIGORTA_ID'] as int?;
    if (sigId == null) { _sn('Önce bir sigorta kaydı seçin'); return; }
    
    final tutar = double.tryParse(fMaliyet.text);
    if (tutar == null || tutar <= 0) { _sn('Maliyet tutarı yok'); return; }
    
    final paid = (_selected?['PAID_TOTAL'] as num?)?.toDouble() ?? 0.0;
    final kalan = tutar - paid;
    
    if (kalan <= 0) {
      _sn('Bu sigorta zaten tamamen ödenmiş');
      return;
    }
    
    // Ödeme tipi seç
    final paymentType = await PaymentTypeDialog.show(
      context: context,
      title: 'Ödeme Tipi Seçin',
      message: 'Kalan tutar: ${kalan.toStringAsFixed(2)} TL',
    );
    
    if (paymentType == null) return; // İptal edildi
    
    try {
      await _payRepo.add(tutar: kalan, tur: 'Sigorta', tipi: paymentType, sigortaId: sigId);
      _sn('Sigorta için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
      UiRouter().go(11, max: 16);
      await _load();
    } catch (e) { _err(e); }
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
        return Icons.check_circle;
      case 'Kısmi':
        return Icons.hourglass_bottom;
      default:
        return Icons.cancel;
    }
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Sigorta/Marka/Model/Plaka ara...'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
          const Spacer(), TextButton.icon(onPressed: () => UiRouter().go(0), icon: const Icon(Icons.home, color: Colors.indigo), label: const Text('Ana Ekran')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _items[i];
              final status = (m['PAY_STATUS'] ?? 'Yok') as String;
              final statusColor = _getStatusColor(status);
              final paid = (m['PAID_TOTAL'] as num?)?.toDouble() ?? 0.0;
              final maliyet = (m['MALIYET'] as num?)?.toDouble() ?? 0.0;
              final kalan = maliyet - paid;
              
              return Card(child: ListTile(
                leading: Icon(_getStatusIcon(status), color: statusColor, size: 32),
                title: Text('Sigorta#${m['SIGORTA_ID']} • ${m['PLAKA']} • ${m['Marka']} ${m['Model']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ad: ${m['SIGORTA_ADI'] ?? '-'} • Kapsam: ${m['KAPSAM_TURU'] ?? '-'} • Maliyet: ${maliyet.toStringAsFixed(2)} TL'),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          status == 'Yok' ? 'ÖDENMEDİ' : status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Ödenen: ${paid.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
                      if (kalan > 0) ...[
                        const SizedBox(width: 8),
                        Text('Kalan: ${kalan.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ]),
                  ],
                ),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton.icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit, size: 18), label: const Text('Düzenle')),
                  if (kalan > 0)
                    FilledButton.icon(
                      onPressed: () { 
                        _fill(m);
                        _quickPay();
                      },
                      icon: const Icon(Icons.payments, size: 18),
                      label: const Text('Öde'),
                    ),
                ]),
                onTap: () => _fill(m),
              ));
            },
          ),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sigorta Ekle/Düzenle', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(children: [ Checkbox(value: aktif, onChanged: (v) => setState(() => aktif = v ?? true)), const Text('Aktif') ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async { final a = await _pickArac(); if (a != null) setState(() => selArac = a); }, icon: const Icon(Icons.directions_car), label: Text(selArac == null ? 'Araç Seç' : '${selArac!['Marka']} ${selArac!['Model']} • ${selArac!['PLAKA']}')),
        const SizedBox(height: 8),
        TextField(controller: fAd, decoration: const InputDecoration(labelText: 'Sigorta Adı')),
        const SizedBox(height: 8),
        TextField(controller: fKapsam, decoration: const InputDecoration(labelText: 'Kapsam Türü')),
        const SizedBox(height: 8),
        TextField(controller: fAciklama, decoration: const InputDecoration(labelText: 'Kapsam Açıklaması')),
        const SizedBox(height: 8),
        TextField(controller: fMaliyet, decoration: const InputDecoration(labelText: 'Maliyet (TL)'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: fBas, decoration: const InputDecoration(labelText: 'Başlangıç (YYYY-MM-DD)')),
        const SizedBox(height: 8),
        TextField(controller: fBit, decoration: const InputDecoration(labelText: 'Bitiş (YYYY-MM-DD)')),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton.icon(onPressed: () => _addOrSave(save: false), icon: const Icon(Icons.add), label: const Text('Ekle')),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _selected == null ? null : () => _addOrSave(save: true), icon: const Icon(Icons.save), label: const Text('Kaydet')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _quickPay, icon: const Icon(Icons.payments), label: const Text('Öde')),
        ]),
      ]))),
    ]);
  }
}