import 'package:flutter/material.dart';
import '../../../data/repositories/campaign_repository.dart';

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});
  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  final _repo = CampaignRepository();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final fAd = TextEditingController();
  final fIndirim = TextEditingController();
  final fKosullar = TextEditingController();
  DateTime? fBas;
  DateTime? fBit;
  bool fAktif = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try { _items = await _repo.listAll(q: _q.text.trim().isEmpty ? null : _q.text.trim()); }
    catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  void _fill(Map<String, dynamic> m) {
    setState(() => _selected = m);
    fAd.text = (m['KAMPANYA_ADI'] ?? '').toString();
    fIndirim.text = ((m['INDIRIM_ORANI'] as num?)?.toString() ?? '');
    fKosullar.text = (m['KOSULLAR'] ?? '').toString();
    fBas = m['BASLANGIC_TARIHI'] == null ? null : DateTime.tryParse(m['BASLANGIC_TARIHI'].toString());
    fBit = m['BITIS_TARIHI'] == null ? null : DateTime.tryParse(m['BITIS_TARIHI'].toString());
    fAktif = (m['AKTIF_MI'] == 1);
  }

  Future<void> _create() async {
    try {
      await _repo.create(
        ad: fAd.text.trim(),
        baslangic: fBas,
        bitis: fBit,
        indirimOrani: double.tryParse(fIndirim.text.trim()),
        kosullar: fKosullar.text.trim().isEmpty ? null : fKosullar.text.trim(),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kampanya eklendi')));
    } catch (e) { _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        kampanyaId: _selected!['KAMPANYA_ID'] as int,
        ad: fAd.text.trim(),
        baslangic: fBas,
        bitis: fBit,
        indirimOrani: double.tryParse(fIndirim.text.trim()),
        kosullar: fKosullar.text.trim().isEmpty ? null : fKosullar.text.trim(),
        aktif: fAktif,
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kampanya güncellendi')));
    } catch (e) { _err(e); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try {
      await _repo.delete(_selected!['KAMPANYA_ID'] as int);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kampanya silindi')));
    } catch (e) { _err(e); }
  }

  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kampanya ara', border: OutlineInputBorder()), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _items[i];
              final aktif = (m['AKTIF_MI'] == 1);
              return Card(child: ListTile(
                leading: Icon(Icons.local_offer, color: aktif ? Colors.green : Colors.grey),
                title: Text('Kampanya#${m['KAMPANYA_ID']} • ${m['KAMPANYA_ADI']}'),
                subtitle: Text('Baş:${m['BASLANGIC_TARIHI'] ?? '-'} • Bit:${m['BITIS_TARIHI'] ?? '-'} • İndirim:${m['INDIRIM_ORANI'] ?? '-'}'),
                onTap: () => _fill(m),
              ));
            },
          )
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_selected == null ? 'Kampanya Ekle' : 'Kampanya Düzenle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(controller: fAd, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final now = DateTime.now(); final d = await showDatePicker(context: context, initialDate: fBas ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => fBas = d); }, icon: const Icon(Icons.date_range), label: Text('Başlangıç: ${fBas?.toString().substring(0, 10) ?? '-'}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final now = DateTime.now().add(const Duration(days: 7)); final d = await showDatePicker(context: context, initialDate: fBit ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => fBit = d); }, icon: const Icon(Icons.date_range), label: Text('Bitiş: ${fBit?.toString().substring(0, 10) ?? '-'}'))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: fIndirim, decoration: const InputDecoration(labelText: 'İndirim Oranı (%)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: fKosullar, maxLines: 3, decoration: const InputDecoration(labelText: 'Koşullar', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [ Checkbox(value: fAktif, onChanged: (v) => setState(() => fAktif = v ?? true)), const Text('Aktif') ]),
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
        ]),
      )),
    ]);
  }
}