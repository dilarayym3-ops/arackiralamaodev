import 'package:flutter/material.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';
import '../../../models/ui_router.dart';

class MaintenancePage extends StatefulWidget { const MaintenancePage({super.key}); @override State<MaintenancePage> createState() => _MaintenancePageState(); }
class _MaintenancePageState extends State<MaintenancePage> {
  final _repo = MaintenanceRepository();
  final _carRepo = CarRepository();
  final _payRepo = pay.PaymentRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _itemsForSelectedCar = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? selArac;
  final fTarih = TextEditingController(text: DateTime.now().toString().substring(0,10));
  final fTur = TextEditingController();
  final fUcret = TextEditingController();
  bool parca = false;
  final fParca = TextEditingController();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try {
      _items = await _repo.listByBranch(Session().current!.subeId, q: _q.text.trim());
      await _refreshSelectedCarList();
    } catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  Future<void> _refreshSelectedCarList() async {
    if (selArac == null) { setState(() => _itemsForSelectedCar = []); return; }
    final s = selArac!['SASE_NO'] as String;
    _itemsForSelectedCar = await _repo.listBySase(s);
    setState(() {});
  }

  @override void initState() { super.initState(); _load(); }

  Future<Map<String, dynamic>?> _pickArac() => SearchSelectDialog.show(
    context, title: 'Araç Seç (Şubedeki araçlar)',
    loader: (q) async => await _carRepo.listDetailedBySube(subeId: Session().current!.subeId, q: q, pageSize: 200),
    itemTitle: (m) => '${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']} (${m['Yil']}) • ${m['PLAKA']}',
    itemSubtitle: (m) => 'Şase: ${m['SASE_NO']} • Durum: ${m['DURUM']}',
  );

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    selArac = {'SASE_NO': m['SASE_NO'], 'PLAKA': m['PLAKA'], 'Marka': m['Marka'], 'Model': m['Model'], 'Seri': m['Seri'], 'Yil': m['Yil']};
    fTarih.text = (m['BAKIM_TARIHI'] ?? '').toString().substring(0,10);
    fTur.text = (m['BAKIM_TURU'] ?? '').toString();
    fUcret.text = (m['BAKIM_UCRETI'] ?? '').toString();
    parca = ((m['PARCA_DEGISTIMI'] ?? 0) == 1);
    fParca.text = (m['DEGISEN_PARCA'] ?? '').toString();
    setState(() {});
  }

  Future<void> _add() async {
    if (selArac == null) { _sn('Araç seçiniz'); return; }
    final tarih = DateTime.tryParse(fTarih.text);
    final ucret = double.tryParse(fUcret.text);
    try {
      await _repo.add(
        saseNo: selArac!['SASE_NO'] as String,
        calisanId: Session().current!.calisanId,
        tarih: tarih ?? DateTime.now(),
        tur: fTur.text.trim().isEmpty ? '-' : fTur.text.trim(),
        ucret: ucret,
        parcaDegisti: parca,
        degisenParca: fParca.text.trim().isEmpty ? null : fParca.text.trim(),
      );
      await _refreshSelectedCarList();
      await _load();
      _sn('Bakım eklendi');
    } catch (e) { _err(e); }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    final tarih = DateTime.tryParse(fTarih.text);
    final ucret = double.tryParse(fUcret.text);
    try {
      await _repo.update(
        bakimId: _selected!['BAKIM_ID'] as int,
        tarih: tarih,
        tur: fTur.text.trim().isEmpty ? null : fTur.text.trim(),
        ucret: ucret,
        parcaDegisti: parca,
        degisenParca: fParca.text.trim().isEmpty ? null : fParca.text.trim(),
      );
      await _refreshSelectedCarList();
      await _load();
      _sn('Bakım güncellendi');
    } catch (e) { _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['BAKIM_ID'] as int);
      await _refreshSelectedCarList();
      await _load();
      _sn('Bakım silindi');
    } catch (e) { _err(e); }
  }

  Future<void> _quickPay() async {
    final ucret = double.tryParse(fUcret.text);
    if (ucret == null || ucret <= 0) { _sn('Bakım ücreti yok'); return; }
    try {
      await _payRepo.add(bakimId: _selected?['BAKIM_ID'] as int?, tutar: ucret, tur: 'Bakım', tipi: 'Nakit');
      UiRouter().go(11, max: 15);
      _sn('Bakım için ödeme eklendi');
      await _refreshSelectedCarList();
    } catch (e) { _err(e); }
  }

  String _payStatusFor(Map<String, dynamic> m) {
    final ucret = (m['BAKIM_UCRETI'] as num?)?.toDouble() ?? 0.0;
    final paid = (m['PAID_TOTAL'] as num?)?.toDouble() ?? 0.0;
    if (ucret <= 0 && paid <= 0) return 'Yok';
    if (paid >= ucret && ucret > 0) return 'Ödendi';
    if (paid > 0) return 'Kısmi';
    return 'Yok';
  }

  Color _statusColor(String s) {
    if (s == 'Ödendi') return Colors.green;
    if (s == 'Kısmi') return Colors.orange;
    return Colors.red;
  }

  Future<List<Map<String, dynamic>>> _itemsWithPaymentStatus(List<Map<String, dynamic>> src) async {
    final list = <Map<String, dynamic>>[];
    for (final m in src) {
      final id = m['BAKIM_ID'] as int;
      final paid = await _payRepo.totalByMaintenance(id);
      m['PAID_TOTAL'] = paid;
      m['PAY_STATUS'] = _payStatusFor({...m, 'PAID_TOTAL': paid});
      list.add(m);
    }
    // ödenmemişler → ödenmişler sıralaması
    list.sort((a,b) {
      final sa = (a['PAY_STATUS'] ?? 'Yok') as String;
      final sb = (b['PAY_STATUS'] ?? 'Yok') as String;
      final ra = sa == 'Ödendi' ? 1 : 0;
      final rb = sb == 'Ödendi' ? 1 : 0;
      return ra.compareTo(rb);
    });
    return list;
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final baseList = (_itemsForSelectedCar.isNotEmpty) ? _itemsForSelectedCar : _items;
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Bakım / Araç / Parça ara...'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
        ])),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _itemsWithPaymentStatus(baseList),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: LinearProgressIndicator());
              final list = snap.data!;
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = list[i];
                  final status = (m['PAY_STATUS'] ?? 'Yok') as String;
                  final color = _statusColor(status);
                  final paid = (m['PAID_TOTAL'] as num?)?.toDouble() ?? 0.0;
                  return Card(child: ListTile(
                    leading: const Icon(Icons.build),
                    title: Text('Bakım#${m['BAKIM_ID']} • ${m['PLAKA'] ?? '-'} • ${m['Marka'] ?? '-'} ${m['Seri'] ?? ''} ${m['Model'] ?? ''}'),
                    subtitle: Text('Tarih: ${m['BAKIM_TARIHI']} • Tür: ${m['BAKIM_TURU'] ?? '-'} • Ücret: ${m['BAKIM_UCRETI'] ?? '-'} • Ödenen: ${paid.toStringAsFixed(2)}'),
                    trailing: Wrap(spacing: 6, runSpacing: 6, children: [
                      Chip(label: Text(status), backgroundColor: color.withOpacity(0.1), labelStyle: TextStyle(color: color)),
                      OutlinedButton.icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit), label: const Text('Düzenle')),
                      FilledButton.icon(onPressed: () { _fill(m); _quickPay(); }, icon: const Icon(Icons.payments), label: const Text('Öde')),
                      OutlinedButton.icon(onPressed: () { _fill(m); _delete(); }, icon: const Icon(Icons.delete), label: const Text('Sil')),
                    ]),
                    onTap: () => _fill(m),
                  ));
                },
              );
            },
          ),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bakım Ekle/Düzenle', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async { final a = await _pickArac(); if (a != null) { setState(() => selArac = a); await _refreshSelectedCarList(); } }, icon: const Icon(Icons.directions_car), label: Text(selArac == null ? 'Araç Seç (Şube)' : '${selArac!['Marka']} ${selArac!['Seri'] ?? ''} ${selArac!['Model']} (${selArac!['Yil']}) • ${selArac!['PLAKA']}')),
        const SizedBox(height: 8),
        TextField(controller: fTarih, decoration: const InputDecoration(labelText: 'Bakım Tarihi (YYYY-MM-DD)')),
        const SizedBox(height: 8),
        TextField(controller: fTur, decoration: const InputDecoration(labelText: 'Bakım Türü')),
        const SizedBox(height: 8),
        TextField(controller: fUcret, decoration: const InputDecoration(labelText: 'Ücret (TL)'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        Row(children: [ Checkbox(value: parca, onChanged: (v) => setState(() => parca = v ?? false)), const Text('Parça Değişimi') ]),
        const SizedBox(height: 8),
        TextField(controller: fParca, decoration: const InputDecoration(labelText: 'Değişen Parça')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Ekle')),
          FilledButton.icon(onPressed: _selected == null ? null : _save, icon: const Icon(Icons.save), label: const Text('Kaydet')),
          OutlinedButton.icon(onPressed: _selected == null ? null : _delete, icon: const Icon(Icons.delete), label: const Text('Sil')),
          OutlinedButton.icon(onPressed: _quickPay, icon: const Icon(Icons.payments), label: const Text('Öde')),
        ]),
      ]))),
    ]);
  }
}