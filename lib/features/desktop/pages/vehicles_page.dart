import 'package:flutter/material.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';

class VehiclesPage extends StatefulWidget { const VehiclesPage({super.key}); @override State<VehiclesPage> createState() => _VehiclesPageState(); }
class _VehiclesPageState extends State<VehiclesPage> {
  final _repo = CarRepository();
  final _modelRepo = ModelRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  String? _error;

  final fSase = TextEditingController();
  final fPlaka = TextEditingController();
  final fKm = TextEditingController();
  final fRenk = TextEditingController();
  String durum = 'Uygun';
  Map<String, dynamic>? selModel;

  bool showOtherBranches = false;

  static const List<String> _durumItems = ['Uygun', 'Kirada', 'Bakımda', 'Kazalı', 'Pasif'];

  String _normalizeDurum(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'Uygun';
    if (v == 'uygun') return 'Uygun';
    if (v == 'kirada') return 'Kirada';
    if (v == 'bakımda' || v == 'bakimda') return 'Bakımda';
    if (v == 'kazalı' || v == 'kazali') return 'Kazalı';
    if (v == 'pasif') return 'Pasif';
    if (v == 'aktif') return 'Uygun';
    return 'Uygun';
  }

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; _items = []; });
    try {
      final term = _q.text.trim();
      if (!showOtherBranches) {
        _items = await _repo.listDetailedBySube(subeId: Session().current!.subeId, q: term.isEmpty ? null : term, pageSize: 200);
      } else {
        _items = await _repo.listAllCarsServerWide(q: term.isEmpty ? null : term);
      }
    } catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  Future<Map<String, dynamic>?> _pickModel() => SearchSelectDialog.show(
    context, title: 'Model Seç',
    loader: (q) async => await _modelRepo.listAll(q: q),
    itemTitle: (m) => '${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']} (${m['Yil']})',
    itemSubtitle: (m) => 'Yakıt: ${m['Yakit_Tipi'] ?? '-'} • Vites: ${m['Vites'] ?? '-'} • Günlük: ${m['GUNLUK_KIRA_BEDELI'] ?? '-'} • Depo: ${m['DEPOZITO_UCRETI'] ?? '-'}',
  );

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    fSase.text = (m['SASE_NO'] ?? '').toString();
    fPlaka.text = (m['PLAKA'] ?? '').toString();
    fKm.text = (m['KM'] ?? '').toString();
    fRenk.text = (m['RENK'] ?? '').toString();
    durum = _normalizeDurum((m['DURUM'] ?? 'Uygun').toString());
    selModel = {
      'MODEL_ID': m['MODEL_ID'],
      'Marka': m['Marka'],
      'Seri': m['Seri'],
      'Model': m['Model'],
      'Yil': m['Yil'],
    };
    setState(() {});
  }

  Future<void> _add() async {
    if (selModel == null) { _sn('Model seçiniz'); return; }
    final km = int.tryParse(fKm.text);
    if (km == null) { _sn('KM sayısal olmalı'); return; }
    if (fSase.text.trim().isEmpty) { _sn('Şase No gerekli'); return; }
    try {
      await _repo.create(
        saseNo: fSase.text.trim(),
        modelId: selModel!['MODEL_ID'] as int,
        subeId: Session().current!.subeId,
        plaka: fPlaka.text.trim(),
        km: km,
        durum: durum,
        renk: fRenk.text.trim().isEmpty ? null : fRenk.text.trim(),
      );
      await _load();
      _sn('Araç eklendi');
    } catch (e) { _err(e); }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    final km = int.tryParse(fKm.text);
    if (km == null) { _sn('KM sayısal olmalı'); return; }
    try {
      await _repo.update(
        saseNo: _selected!['SASE_NO'] as String,
        modelId: selModel?['MODEL_ID'] as int?,
        plaka: fPlaka.text.trim().isEmpty ? null : fPlaka.text.trim(),
        km: km,
        durum: durum,
        renk: fRenk.text.trim().isEmpty ? null : fRenk.text.trim(),
      );
      await _load();
      _sn('Araç güncellendi');
    } catch (e) { _err(e); }
  }

  Future<void> _softDelete() async {
    if (_selected == null) return;
    try {
      await _repo.update(saseNo: _selected!['SASE_NO'] as String, durum: 'Pasif');
      await _load();
      _sn('Araç pasife alındı (soft-delete)');
    } catch (e) { _err(e); }
  }

  Future<void> _hardDelete() async {
    if (_selected == null) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Silme Onayı'),
      content: Text('Araç ${_selected!['PLAKA']} tamamen silinsin mi? Bu geri alınamaz.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      // KIRALAMA FK’leri varsa DB engel çıkarabilir; burada demo olarak doğrudan silme varsayımı yapıyoruz.
      await _repo.update(saseNo: _selected!['SASE_NO'] as String, durum: 'Pasif'); // güvenli geçiş
      // Eğer gerçek DELETE gerekecekse backend’de ayrı endpoint yazılı olmalı.
      _sn('Silme işlemi için Pasif’e alındı. (Tam silme için DB tarafında izin gerekli)');
      await _load();
    } catch (e) { _err(e); }
  }

  Future<void> _transferToMe() async {
    if (_selected == null) return;
    final sid = (_selected!['GUNCEL_SUBE_ID'] as int?) ?? 0;
    final my = Session().current!.subeId;
    if (sid == my) { _sn('Araç zaten bu şubede'); return; }
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Transfer Onayı'),
      content: Text('Araç ${_selected!['PLAKA']} mevcut şubeden sizin şubenize transfer edilsin mi?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Transfer Et')),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      await _repo.transferToBranch(saseNo: _selected!['SASE_NO'] as String, targetSubeId: my);
      await _load();
      _sn('Araç şubenize transfer edildi');
    } catch (e) { _err(e); }
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final mySube = Session().current!.subeId;
    final canTransfer = showOtherBranches && _selected != null && ((_selected!['GUNCEL_SUBE_ID'] as int?) ?? mySube) != mySube;

    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Plaka / Marka / Seri / Model ara'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
          const SizedBox(width: 8),
          TextButton.icon(onPressed: () => setState(() { showOtherBranches = !showOtherBranches; _load(); }), icon: const Icon(Icons.swap_horiz), label: Text(showOtherBranches ? 'Tüm şubeler' : 'Sadece aktif şube')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _items[i];
              final otherLbl = showOtherBranches ? ' • ŞubeID:${m['GUNCEL_SUBE_ID']}' : '';
              return Card(child: ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text('${m['PLAKA']} • ${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']} (${m['Yil']})$otherLbl'),
                subtitle: Text('KM: ${m['KM']} • Durum: ${m['DURUM'] ?? '-'} • Renk: ${m['RENK'] ?? '-'}'),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton.icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit), label: const Text('Seç')),
                  if (canTransfer) FilledButton.icon(onPressed: _transferToMe, icon: const Icon(Icons.publish), label: const Text('Şubeme Transfer Et')),
                ]),
                onTap: () => _fill(m),
              ));
            },
          ),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Araç Ekle/Düzenle', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async { final mdl = await _pickModel(); if (mdl != null) setState(() => selModel = mdl); }, icon: const Icon(Icons.directions_car), label: Text(selModel == null ? 'Model Seç' : '${selModel!['Marka']} ${selModel!['Seri'] ?? ''} ${selModel!['Model']} (${selModel!['Yil']})')),
        const SizedBox(height: 8),
        TextField(controller: fSase, decoration: const InputDecoration(labelText: 'Şase No', helperText: '17 karakter'), maxLength: 17),
        const SizedBox(height: 8),
        TextField(controller: fPlaka, decoration: const InputDecoration(labelText: 'Plaka')),
        const SizedBox(height: 8),
        TextField(controller: fKm, decoration: const InputDecoration(labelText: 'KM'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: fRenk, decoration: const InputDecoration(labelText: 'Renk')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _normalizeDurum(durum),
          items: _durumItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => durum = _normalizeDurum(v)),
          decoration: const InputDecoration(labelText: 'Durum'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Ekle')),
          FilledButton.icon(onPressed: _selected == null ? null : _save, icon: const Icon(Icons.save), label: const Text('Kaydet')),
          OutlinedButton.icon(onPressed: _selected == null ? null : _softDelete, icon: const Icon(Icons.delete), label: const Text('Pasife Al (Soft)')),
          OutlinedButton.icon(onPressed: _selected == null ? null : _hardDelete, icon: const Icon(Icons.delete_forever), label: const Text('Araç Sil')),
        ]),
      ]))),
    ]);
  }
}