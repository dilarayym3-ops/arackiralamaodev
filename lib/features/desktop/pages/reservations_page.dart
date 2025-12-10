import 'package:flutter/material.dart';
import '../../../data/repositories/reservation_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/campaign_repository.dart';
import '../../../data/repositories/sube_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';
import '../../../models/ui_router.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _repo = ReservationRepository();
  final _customerRepo = CustomerRepository();
  final _campaignRepo = CampaignRepository();
  final _subeRepo = SubeRepository();
  final _modelRepo = ModelRepository();

  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? selMusteri, selModel, selAlisSube, selTeslimSube, selKampanya;
  DateTime? selAlis, selTeslim;

  // YENI: Model seçiminde “diğer şubeler”i gösterme anahtarı
  bool showOtherBranchesForModel = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; _items = []; });
    try {
      _items = await _repo.listBySube(Session().current!.subeId, q: _q.text.trim().isEmpty ? null : _q.text.trim());
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _pickMusteri() => SearchSelectDialog.show(
    context,
    title: 'Müşteri Seç',
    loader: (q) async => await _customerRepo.listAll(q: q),
    itemTitle: (m) => '${m['AD']} ${m['SOYAD']} • TC: ${m['TC_NO']}',
    itemSubtitle: (m) => '${m['TELEFON']} • ${m['E-MAIL']}',
  );

  // GÜNCEL: Model seçimi — varsayılan bu şubedeki Uygun araçlara ait modeller,
  // istenirse buton ile diğer şubelerdeki uygun modeller listelenir (şube adıyla).
  Future<Map<String, dynamic>?> _pickModel() => SearchSelectDialog.show(
    context,
    title: showOtherBranchesForModel ? 'Model Seç (Diğer şubelerdeki uygun araçlar)' : 'Model Seç (Bu şubedeki uygun araçlar)',
    loader: (q) async {
      final sid = Session().current!.subeId;
      if (showOtherBranchesForModel) {
        return await _modelRepo.listAvailableInOtherBranches(sid, q: q);
      } else {
        return await _modelRepo.listAvailableInBranch(sid, q: q);
      }
    },
    itemTitle: (m) => '${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']} (${m['Yil']})',
    itemSubtitle: (m) {
      final gunluk = (m['GUNLUK_KIRA_BEDELI'] ?? '').toString();
      final depo = (m['DEPOZITO_UCRETI'] ?? '').toString();
      final subeAdi = m['SUBE_ADI'];
      return showOtherBranchesForModel
          ? 'Şube: ${subeAdi ?? '-'} • Günlük: $gunluk • Depo: $depo'
          : 'Günlük: $gunluk • Depo: $depo';
    },
  );

  Future<Map<String, dynamic>?> _pickSube(String title) => SearchSelectDialog.show(
    context,
    title: title,
    loader: (q) async {
      final rows = await _subeRepo.getAll();
      final t = q.toLowerCase();
      return rows.where((s) =>
        (s['SUBE_ADI'] ?? '').toString().toLowerCase().contains(t) ||
        (s['IL'] ?? '').toString().toLowerCase().contains(t) ||
        (s['ILCE'] ?? '').toString().toLowerCase().contains(t)
      ).toList();
    },
    itemTitle: (s) => '${s['SUBE_ADI']}',
    itemSubtitle: (s) => '${s['IL']}/${s['ILCE']}',
  );

  Future<Map<String, dynamic>?> _pickCampaign() => SearchSelectDialog.show(
    context,
    title: 'Kampanya (Ops.)',
    loader: (q) async => await _campaignRepo.listAll(q: q),
    itemTitle: (m) => '${m['KAMPANYA_ADI'] ?? ''}',
    itemSubtitle: (m) => 'İndirim: ${m['INDIRIM_ORANI'] ?? '-'} • ${((m['AKTIF_MI'] ?? 1) == 1) ? 'Aktif' : 'Pasif'}',
  );

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
  }

  Future<void> _create() async {
    if (selMusteri == null || selModel == null || selAlisSube == null || selTeslimSube == null || selAlis == null || selTeslim == null) {
      _sn('Tüm alanları doldurun'); return;
    }
    try {
      await _repo.create(
        musteriId: selMusteri!['MUSTERI_ID'] as int,
        modelId: selModel!['MODEL_ID'] as int,
        alisSubeId: selAlisSube!['SUBE_ID'] as int,
        teslimSubeId: selTeslimSube!['SUBE_ID'] as int,
        alis: selAlis!,
        teslim: selTeslim!,
        kampanyaId: selKampanya?['KAMPANYA_ID'] as int?,
      );
      selMusteri = null; selModel = null; selAlisSube = null; selTeslimSube = null; selAlis = null; selTeslim = null; selKampanya = null;
      await _load();
      _sn('Rezervasyon eklendi');
    } catch (e) { _err(e); }
  }

  Future<void> _saveSelected() async {
    if (_selected == null) return;
    try {
      await _repo.updateStatus(_selected!['REZERVASYON_ID'] as int, 'Güncellendi');
      await _load();
      _sn('Rezervasyon güncellendi');
    } catch (e) { _err(e); }
  }

  Future<void> _deleteSelected() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['REZERVASYON_ID'] as int);
      await _load();
      _sn('Rezervasyon silindi');
    } catch (e) {
      // FK engeli varsa soft-delete: durum 'İptal'
      try {
        await _repo.updateStatus(_selected!['REZERVASYON_ID'] as int, 'İptal');
        await _load();
        _sn('Rezervasyon iptal edildi (soft-delete)');
      } catch (e2) { _err(e2); }
    }
  }

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rezervasyon / Marka / Model / Müşteri ara'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.search), label: const Text('Ara')),
          const Spacer(), TextButton.icon(onPressed: () => UiRouter().go(0), icon: const Icon(Icons.home, color: Colors.indigo), label: const Text('Ana Ekran')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(Icons.event_available),
                        title: Text('Rez#${m['REZERVASYON_ID']} • ${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']}'),
                        subtitle: Text('Alış: ${m['PLANLANAN_ALIS_TARIHI']} • Teslim: ${m['PLANLANAN_TESLIM_TARIHI']} • Durum: ${m['REZERVASYON_DURUMU']}'),
                        onTap: () => _fill(m),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: OverflowBar(
                          alignment: MainAxisAlignment.start,
                          spacing: 8,
                          overflowSpacing: 8,
                          children: [
                            FilledButton.icon(onPressed: () => setState(() => _selected = m), icon: const Icon(Icons.edit), label: const Text('Seç')),
                            FilledButton.icon(onPressed: _selected == null ? null : _saveSelected, icon: const Icon(Icons.save), label: const Text('Güncelle')),
                            OutlinedButton.icon(onPressed: _selected == null ? null : _deleteSelected, icon: const Icon(Icons.delete), label: const Text('Sil')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rezervasyon Ekle/Düzenle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async { final r = await _pickMusteri(); if (r != null) setState(() => selMusteri = r); }, icon: const Icon(Icons.person_search), label: Text(selMusteri == null ? 'Müşteri Seç' : 'Müşteri seçildi')),
          const SizedBox(height: 8),

          // YENI: Diğer şubelerdeki modelleri göstermek için anahtar
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async { final m = await _pickModel(); if (m != null) setState(() => selModel = m); },
                icon: const Icon(Icons.directions_car),
                label: Text(selModel == null ? (showOtherBranchesForModel ? 'Model Seç (Diğer şubeler)' : 'Model Seç (Bu şube)') : '${selModel!['Marka']} ${selModel!['Seri'] ?? ''} ${selModel!['Model']} (${selModel!['Yil']})'),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Model seçerken bu şube/diger şubeler arasında geçiş yap',
              child: OutlinedButton(
                onPressed: () => setState(() => showOtherBranchesForModel = !showOtherBranchesForModel),
                child: Text(showOtherBranchesForModel ? 'Diğer Şubeler' : 'Bu Şube'),
              ),
            ),
          ]),

          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final s = await _pickSube('Alış Şube'); if (s != null) setState(() => selAlisSube = s); }, icon: const Icon(Icons.home_work), label: Text(selAlisSube == null ? 'Alış Şube' : '${selAlisSube!['SUBE_ADI']}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final s = await _pickSube('Teslim Şube'); if (s != null) setState(() => selTeslimSube = s); }, icon: const Icon(Icons.home_work), label: Text(selTeslimSube == null ? 'Teslim Şube' : '${selTeslimSube!['SUBE_ADI']}'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final now = DateTime.now(); final d = await showDatePicker(context: context, initialDate: selAlis ?? now, firstDate: now, lastDate: DateTime(2100)); if (d != null) setState(() => selAlis = d); }, icon: const Icon(Icons.date_range), label: Text('Alış: ${selAlis?.toString().substring(0, 10) ?? '-'}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final now = DateTime.now().add(const Duration(days: 3)); final d = await showDatePicker(context: context, initialDate: selTeslim ?? now, firstDate: DateTime.now(), lastDate: DateTime(2100)); if (d != null) setState(() => selTeslim = d); }, icon: const Icon(Icons.date_range), label: Text('Teslim: ${selTeslim?.toString().substring(0, 10) ?? '-'}'))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async { final k = await _pickCampaign(); if (k != null) setState(() => selKampanya = k); }, icon: const Icon(Icons.campaign), label: Text(selKampanya == null ? 'Kampanya (Ops.)' : '${selKampanya!['KAMPANYA_ADI']}')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Oluştur')),
              FilledButton.icon(onPressed: _selected == null ? null : _saveSelected, icon: const Icon(Icons.save), label: const Text('Seçiliyi Güncelle')),
              OutlinedButton.icon(onPressed: _selected == null ? null : _deleteSelected, icon: const Icon(Icons.delete), label: const Text('Seçiliyi Sil')),
            ],
          ),
        ]),
      )),
    ]);
  }
}