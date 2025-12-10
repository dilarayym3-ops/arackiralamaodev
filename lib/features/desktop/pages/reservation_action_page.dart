import 'package:flutter/material.dart';
import '../../../data/repositories/reservation_repository.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/rental_repository.dart';
import '../../../data/repositories/sube_repository.dart';
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';

class ReservationActionPage extends StatefulWidget {
  const ReservationActionPage({super.key});
  @override
  State<ReservationActionPage> createState() => _ReservationActionPageState();
}

class _ReservationActionPageState extends State<ReservationActionPage> {
  final _repo = ReservationRepository();
  final _carRepo = CarRepository();
  final _rentRepo = RentalRepository();
  final _subeRepo = SubeRepository();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? selKarsilamaSube;
  Map<String, dynamic>? selArac;
  int? selAlisKm;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; selArac = null; });
    try {
      final branchId = Session().current!.subeId;
      _items = await _repo.listServiceableByBranch(branchId);
    } catch (e) { _error = e.toString(); }
    finally { setState(() => _loading = false); }
  }

  Future<Map<String, dynamic>?> _pickKarsilamaSube() => SearchSelectDialog.show(
    context, title: 'Karşılanacak Şube Seç',
    loader: (q) async {
      final rows = await _subeRepo.getAll();
      final term = q.toLowerCase();
      return rows.where((s) =>
        (s['SUBE_ADI'] ?? '').toString().toLowerCase().contains(term) ||
        (s['IL'] ?? '').toString().toLowerCase().contains(term) ||
        (s['ILCE'] ?? '').toString().toLowerCase().contains(term)
      ).toList();
    },
    itemTitle: (s) => '${s['SUBE_ADI'] ?? ''}',
    itemSubtitle: (s) => '${s['IL'] ?? ''}/${s['ILCE'] ?? ''}',
  );

  Future<Map<String, dynamic>?> _pickAracForReservation(Map<String, dynamic> rez, int karsilamaSubeId) {
    final modelId = rez['MODEL_ID'] as int;
    return SearchSelectDialog.show(
      context,
      title: 'Araç Seç (Seçilen şubedeki, aynı model)',
      loader: (q) async {
        final list = await _carRepo.listDetailedBySube(subeId: karsilamaSubeId, q: q, pageSize: 200);
        return list.where((c) =>
          (c['MODEL_ID'] as int) == modelId &&
          ((c['DURUM'] ?? '').toString().toLowerCase() == 'uygun')
        ).toList();
      },
      itemTitle: (m) => '${m['Marka']} ${m['Model']} (${m['Yil']}) • ${m['PLAKA']}',
      itemSubtitle: (m) => 'KM: ${m['KM']} • Şase: ${m['SASE_NO']} • Günlük: ${m['GUNLUK_KIRA_BEDELI']} • Depo: ${m['DEPOZITO_UCRETI']}',
    );
  }

  Future<void> _startRentalFromReservation() async {
    if (_selected == null || selKarsilamaSube == null || selArac == null || selAlisKm == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rezervasyon, karşılanacak şube, araç ve alış KM gerekli')));
      return;
    }
    try {
      await _rentRepo.open(
        musteriId: _selected!['MUSTERI_ID'] as int,
        saseNo: selArac!['SASE_NO'] as String,
        alisCalisanId: Session().current!.calisanId,
        alisSubeId: selKarsilamaSube!['SUBE_ID'] as int, // karşılanacak şube
        planlananTeslim: DateTime.parse(_selected!['PLANLANAN_TESLIM_TARIHI'].toString()),
        alisKm: selAlisKm!,
        gunlukBedel: (selArac!['GUNLUK_KIRA_BEDELI'] as num).toDouble(),
        depozito: (selArac!['DEPOZITO_UCRETI'] as num).toDouble(),
        rezervasyonId: _selected!['REZERVASYON_ID'] as int,
      );
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiralama başlatıldı (rezervasyonla)')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyonla İşlem')),
      body: Row(children: [
        Expanded(flex: 2, child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Text('Rezervasyonlar', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Yenile')),
          ])),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _error != null ? Center(child: Text('Hata: $_error'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _items[i];
                  final uyg = (m['UygunAracSayisi'] as num?)?.toInt() ?? 0;
                  return Card(
                    child: ListTile(
                      leading: Icon(uyg > 0 ? Icons.event_available : Icons.report, color: uyg > 0 ? Colors.green : Colors.red),
                      title: Text('Rez#${m['REZERVASYON_ID']} • ${m['Marka']} ${m['Model']}'),
                      subtitle: Text('Alış Şube: ${m['ALIS_SUBE_ADI']} • Teslim Şube: ${m['TESLIM_SUBE_ADI']} • Uygun Araç: $uyg'),
                      onTap: () => setState(() => _selected = m),
                    ),
                  );
                },
              )),
        ])),
        const VerticalDivider(width: 1),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İşlem', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final s = await _pickKarsilamaSube();
                if (s != null) setState(() => selKarsilamaSube = s);
              },
              icon: const Icon(Icons.home_work),
              label: Text(selKarsilamaSube == null ? 'Karşılanacak Şube Seç' : '${selKarsilamaSube!['SUBE_ADI']}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_selected == null || selKarsilamaSube == null) ? null : () async {
                final a = await _pickAracForReservation(_selected!, selKarsilamaSube!['SUBE_ID'] as int);
                if (a != null) setState(() => selArac = a);
              },
              icon: const Icon(Icons.car_rental),
              label: Text(selArac == null ? 'Araç Seç (Şubedeki, aynı model)' : '${selArac!['Marka']} ${selArac!['Model']} • ${selArac!['PLAKA']}'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Alış KM'),
              keyboardType: TextInputType.number,
              onChanged: (v) => selAlisKm = int.tryParse(v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _startRentalFromReservation, icon: const Icon(Icons.play_arrow), label: const Text('Kiralama Başlat')),
          ]),
        )),
      ]),
    );
  }
}