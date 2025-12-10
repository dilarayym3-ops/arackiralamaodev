import 'package:flutter/material.dart';
import '../../../data/repositories/rental_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/car_repository.dart';
import '../../../data/repositories/reservation_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/sube_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/fine_repository.dart';
import '../../../data/repositories/insurance_repository.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../data/repositories/accident_repository.dart';
import '../../../data/repositories/campaign_repository.dart';
import '../../../models/session.dart';
import '../../../models/ui_router.dart';
import '../../../widgets/search_select_dialog.dart';

class RentalsPage extends StatefulWidget {
  const RentalsPage({super.key});
  @override
  State<RentalsPage> createState() => _RentalsPageState();
}

class _RentalsPageState extends State<RentalsPage> {
  final _repo = RentalRepository();
  final _customerRepo = CustomerRepository();
  final _carRepo = CarRepository();
  final _reservationRepo = ReservationRepository();
  final _empRepo = EmployeeRepository();
  final _subeRepo = SubeRepository();

  final _serviceRepo = ServiceRepository();
  final _paymentRepo = PaymentRepository();
  final _fineRepo = FineRepository();
  final _insRepo = InsuranceRepository();
  final _mntRepo = MaintenanceRepository();
  final _accRepo = AccidentRepository();
  final _campRepo = CampaignRepository();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;
  String _filter = 'Açık';

  // Başlat formu
  Map<String, dynamic>? selMusteri;
  Map<String, dynamic>? selArac;
  DateTime? selPlanTeslim;
  int? selAlisKm;
  double? selGunluk;
  double? selDepo;
  Map<String, dynamic>? selRez;
  Map<String, dynamic>? selCamp;

  // Bitir formu
  Map<String, dynamic>? selTeslimCalisan;
  Map<String, dynamic>? selTeslimSube;
  DateTime? cGercekTeslim;
  final cDonusKm = TextEditingController();
  final cToplam = TextEditingController();

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
      _items = await _repo.listBySube(Session().current!.subeId, durum: _filter);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Dialog pickers
  Future<Map<String, dynamic>?> _pickMusteri() => SearchSelectDialog.show(
        context,
        title: 'Müşteri Seç',
        loader: (q) async => await _customerRepo.listAll(q: q),
        itemTitle: (m) => '${m['AD']} ${m['SOYAD']} • TC: ${m['TC_NO']}',
        itemSubtitle: (m) => '${m['TELEFON']} • ${m['E-MAIL']}',
      );

  Future<Map<String, dynamic>?> _pickArac() => SearchSelectDialog.show(
        context,
        title: 'Araç Seç',
        loader: (q) async {
          final list = await _carRepo.listDetailedBySube(subeId: Session().current!.subeId, q: q, pageSize: 200);
          return list.where((c) => (c['DURUM'] ?? '').toString().toLowerCase() == 'uygun').toList();
        },
        itemTitle: (m) => '${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']} (${m['Yil']}) • ${m['PLAKA']}',
        itemSubtitle: (m) => 'KM: ${m['KM']} • Şase: ${m['SASE_NO']} • Günlük: ${m['GUNLUK_KIRA_BEDELI']} • Depo: ${m['DEPOZITO_UCRETI']}',
      );

  Future<Map<String, dynamic>?> _pickRezervasyon() => SearchSelectDialog.show(
        context,
        title: 'Rezervasyon Seç (Ops.)',
        loader: (q) async {
          final rows = await _reservationRepo.listBySube(Session().current!.subeId, q: q);
          return rows.where((r) => ((r['REZERVASYON_DURUMU'] ?? '').toString().toLowerCase() != 'iptal')).toList();
        },
        itemTitle: (r) => 'Rez#${r['REZERVASYON_ID']} • ${r['Marka']} ${r['Seri'] ?? ''} ${r['Model']}',
        itemSubtitle: (r) => 'Alış: ${r['PLANLANAN_ALIS_TARIHI']} • Teslim: ${r['PLANLANAN_TESLIM_TARIHI']}',
      );

  Future<Map<String, dynamic>?> _pickCampaign() => SearchSelectDialog.show(
        context,
        title: 'Kampanya Seç (Ops.)',
        loader: (q) async => await _campRepo.listAll(q: q),
        itemTitle: (m) => '${m['KAMPANYA_ADI']}',
        itemSubtitle: (m) => 'İndirim: ${m['INDIRIM_ORANI']}%',
      );

  Future<Map<String, dynamic>?> _pickEmployeeByBranch(int subeId) => SearchSelectDialog.show(
        context,
        title: 'Teslim Çalışan Seç',
        loader: (q) async => await _empRepo.listBySube(subeId, q: q),
        itemTitle: (e) => '${e['AD']} ${e['SOYAD']}',
        itemSubtitle: (e) => '${e['E-MAIL']} • ${e['POZISYON'] ?? ''}',
      );

  Future<Map<String, dynamic>?> _pickSube() => SearchSelectDialog.show(
        context,
        title: 'Teslim Şube Seç',
        loader: (q) async {
          final rows = await _subeRepo.getAll();
          final t = q.toLowerCase();
          return rows
              .where((s) =>
                  (s['SUBE_ADI'] ?? '').toString().toLowerCase().contains(t) ||
                  (s['IL'] ?? '').toString().toLowerCase().contains(t) ||
                  (s['ILCE'] ?? '').toString().toLowerCase().contains(t))
              .toList();
        },
        itemTitle: (s) => '${s['SUBE_ADI']}',
        itemSubtitle: (s) => '${s['IL']}/${s['ILCE']}',
      );

  // Kiralama açarken rezervasyonu uygula
  void _applyReservation(Map<String, dynamic> r) async {
    selRez = r;
    selMusteri = {'MUSTERI_ID': r['MUSTERI_ID']};
    final modelId = r['MODEL_ID'] as int;
    final list = await _carRepo.listDetailedBySube(subeId: Session().current!.subeId, q: null, pageSize: 200);
    final candidates = list
        .where((c) => (c['MODEL_ID'] as int) == modelId && ((c['DURUM'] ?? '').toString().toLowerCase() == 'uygun'))
        .toList();
    if (candidates.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçili rezervasyon modeli için uygun araç bu şubede yok')));
      return;
    }
    final c = candidates.first;
    selArac = c;
    selGunluk = (c['GUNLUK_KIRA_BEDELI'] as num).toDouble();
    selDepo = (c['DEPOZITO_UCRETI'] as num).toDouble();
    selPlanTeslim = DateTime.tryParse(r['PLANLANAN_TESLIM_TARIHI'].toString());
    setState(() {});
  }

  Future<void> _open() async {
    if (selMusteri == null || selArac == null || selPlanTeslim == null || selAlisKm == null || selGunluk == null || selDepo == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tüm alanları doldurunuz')));
      return;
    }
    final rezId = selRez?['REZERVASYON_ID'] as int?;
    if (rezId != null) {
      final rezModelId = selRez!['MODEL_ID'] as int;
      final carModelId = selArac!['MODEL_ID'] as int;
      if (rezModelId != carModelId) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rezervasyon modeli ile araç modeli uyuşmuyor')));
        return;
      }
    }
    try {
      await _repo.open(
        musteriId: selMusteri!['MUSTERI_ID'] as int,
        saseNo: selArac!['SASE_NO'] as String,
        alisCalisanId: Session().current!.calisanId,
        alisSubeId: Session().current!.subeId,
        planlananTeslim: selPlanTeslim!,
        alisKm: selAlisKm!,
        gunlukBedel: selGunluk!,
        depozito: selDepo!,
        rezervasyonId: rezId,
      );
      // Kampanya indirimi ödeme olarak yansıt
      if (selCamp != null) {
        final ind = (selCamp!['INDIRIM_ORANI'] as num?)?.toDouble() ?? 0.0;
        if (ind > 0 && selGunluk != null) {
          final indir = selGunluk! * ind / 100.0;
          final tutar = (selGunluk! - indir).clamp(0.0, double.infinity);
          await _paymentRepo.add(
            kiralamaId: null,
            cezaId: null,
            sigortaId: null,
            bakimId: null,
            kazaId: null,
            tutar: tutar,
            tur: 'Kira',
            tipi: 'Kampanya',
          );
        }
      }
      _clearOpen();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiralama başlatıldı')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _finishRentalProcess() async {
    if (_selected == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiralama seçiniz')));
      return;
    }
    if (selTeslimSube == null || selTeslimCalisan == null || cGercekTeslim == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teslim şube, çalışan ve tarih gerekli')));
      return;
    }
    try {
      await _repo.close(
        kiralamaId: _selected!['KIRALAMA_ID'] as int,
        teslimCalisanId: selTeslimCalisan!['CALISAN_ID'] as int,
        teslimSubeId: selTeslimSube!['SUBE_ID'] as int,
        gercekTeslim: cGercekTeslim!,
        donusKm: int.tryParse(cDonusKm.text) ?? (_selected!['ALIS_KM'] as int),
        toplamTutar: double.tryParse(cToplam.text) ?? 0,
      );
      _clearClose();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiralama süreci başarıyla bitti')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  void _clearOpen() {
    selMusteri = null;
    selArac = null;
    selPlanTeslim = null;
    selAlisKm = null;
    selGunluk = null;
    selDepo = null;
    selRez = null;
    selCamp = null;
  }

  void _clearClose() {
    selTeslimCalisan = null;
    selTeslimSube = null;
    cGercekTeslim = null;
    cDonusKm.clear();
    cToplam.clear();
  }

  void _pickCloseDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: cGercekTeslim ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => cGercekTeslim = d);
  }

  // Seçili kiralama için özet ve bağlı kalemler — düzenleme/ekleme/silme destekli
  Widget _detailsExpanded() {
    if (_selected == null) return const SizedBox.shrink();
    final kiralamaId = _selected!['KIRALAMA_ID'] as int;
    final saseNo = _selected!['SASE_NO'] as String? ?? '';

    // Form alanları
    final fPlanTeslim = TextEditingController(text: (_selected!['PLANLANAN_TESLIM_TARIHI'] ?? '').toString());
    final fGercekTeslim = TextEditingController(text: (_selected!['GERCEKLESEN_TESLIM_TARIHI'] ?? '').toString());
    final fDonusKm2 = TextEditingController(text: (_selected!['DONUS_KM'] ?? '').toString());
    final fToplam2 = TextEditingController(text: (_selected!['TOPLAM_KIRA_TUTARI'] ?? '').toString());
    final fGunluk2 = TextEditingController(text: (_selected!['KIRA_GUNLUK_BEDEL'] ?? '').toString());
    final fDepo2 = TextEditingController(text: (_selected!['ALINAN_DEPOZITO'] ?? '').toString());
    final fDepoDurum2 = TextEditingController(text: (_selected!['DEPOZITO_DURUMU'] ?? '').toString());

    Map<String, dynamic>? selPaymentRow;
    final upPayTutar = TextEditingController();
    String upPayTur = 'Kira';
    String upPayTip = 'Nakit';

    Map<String, dynamic>? selFineRow;
    final fineTarih = TextEditingController();
    final fineTur = TextEditingController();
    final fineTutar = TextEditingController();

    Map<String, dynamic>? selInsRow;
    final insAd = TextEditingController();
    final insKapsam = TextEditingController();
    final insAciklama = TextEditingController();
    final insMaliyet = TextEditingController();
    final insBas = TextEditingController();
    final insBit = TextEditingController();
    bool insAktif = true;

    Map<String, dynamic>? selMntRow;
    final mntTarih = TextEditingController();
    final mntTur = TextEditingController();
    final mntUcret = TextEditingController();
    bool mntParca = false;
    final mntParcaAd = TextEditingController();

    Map<String, dynamic>? selAccRow;
    final accTarih = TextEditingController();
    final accHasarTur = TextEditingController();
    final accHasarMiktar = TextEditingController();
    final accSigortaDurum = TextEditingController();

    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: Future.wait([
        _paymentRepo.listByRental(kiralamaId),
        _fineRepo.listByRental(kiralamaId),
        _insRepo.listBySase(saseNo),
        _mntRepo.listBySase(saseNo),
        _accRepo.listByBranch(Session().current!.subeId, q: kiralamaId.toString()),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
        final pays = snap.data![0];
        final fines = snap.data![1];
        final ins = snap.data![2];
        final mnts = snap.data![3];
        final accs = snap.data![4].where((a) => (a['KIRALAMA_ID'] as int?) == kiralamaId).toList();

        void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
        void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Genel Detay (Düzenlenebilir)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            TextField(controller: fPlanTeslim, decoration: const InputDecoration(labelText: 'Planlanan Teslim (ISO8601)')),
            const SizedBox(height: 8),
            TextField(controller: fGercekTeslim, decoration: const InputDecoration(labelText: 'Gerçek Teslim (ISO8601)')),
            const SizedBox(height: 8),
            TextField(controller: fDonusKm2, decoration: const InputDecoration(labelText: 'Dönüş KM'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: fToplam2, decoration: const InputDecoration(labelText: 'Toplam Kira Tutarı (TL)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: fGunluk2, decoration: const InputDecoration(labelText: 'Günlük Bedel (TL)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: fDepo2, decoration: const InputDecoration(labelText: 'Alınan Depozito (TL)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: fDepoDurum2, decoration: const InputDecoration(labelText: 'Depozito Durumu')),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await _repo.updatePartial(
                    kiralamaId: kiralamaId,
                    planlananTeslim: DateTime.tryParse(fPlanTeslim.text),
                    gercekTeslim: DateTime.tryParse(fGercekTeslim.text),
                    donusKm: int.tryParse(fDonusKm2.text),
                    toplamKira: double.tryParse(fToplam2.text),
                    gunlukBedel: double.tryParse(fGunluk2.text),
                    depozito: double.tryParse(fDepo2.text),
                    depozitoDurumu: fDepoDurum2.text.trim().isEmpty ? null : fDepoDurum2.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Genel detaylar güncellendi')));
                  await _load();
                } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red)); }
              },
              icon: const Icon(Icons.save),
              label: const Text('Kaydet'),
            ),
            const Divider(),

            // Ödemeler — düzenle/sil
            Text('Ödemeler (${pays.length})', style: Theme.of(context).textTheme.titleSmall),
            ...pays.map((p) => ListTile(
              leading: const Icon(Icons.payments),
              title: Text('Ödeme#${p['ODEME_ID']} • ${p['ODEME_TURU'] ?? '-'} • ${(p['ODEME_TUTARI'] ?? '-').toString()} TL'),
              subtitle: Text('Tip: ${p['ODEME_TIPI'] ?? '-'}'),
              trailing: OverflowBar(spacing: 6, overflowSpacing: 6, children: [
                OutlinedButton(onPressed: () { selPaymentRow = p; upPayTutar.text = (p['ODEME_TUTARI'] ?? '').toString(); upPayTur = (p['ODEME_TURU'] ?? 'Kira').toString(); upPayTip = (p['ODEME_TIPI'] ?? 'Nakit').toString(); setState((){}); }, child: const Text('Düzenle')),
                OutlinedButton(onPressed: () async { try { await _paymentRepo.delete(p['ODEME_ID'] as int); _sn('Ödeme silindi'); setState(()=>selPaymentRow=null); } catch (e) { _err(e); } }, child: const Text('Sil')),
              ]),
            )),
            if (selPaymentRow != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ödeme Düzenle: #${selPaymentRow!['ODEME_ID']}'),
                const SizedBox(height: 8),
                TextField(controller: upPayTutar, decoration: const InputDecoration(labelText: 'Tutar (TL)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(value: upPayTur, items: const [
                  DropdownMenuItem(value: 'Kira', child: Text('Kira')),
                  DropdownMenuItem(value: 'Depozito', child: Text('Depozito')),
                  DropdownMenuItem(value: 'İade', child: Text('İade')),
                  DropdownMenuItem(value: 'Ceza', child: Text('Ceza')),
                  DropdownMenuItem(value: 'Sigorta', child: Text('Sigorta')),
                  DropdownMenuItem(value: 'Bakım', child: Text('Bakım')),
                  DropdownMenuItem(value: 'Kaza', child: Text('Kaza')),
                  DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                ], onChanged: (v) => setState(() => upPayTur = v ?? upPayTur), decoration: const InputDecoration(labelText: 'Tür')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(value: upPayTip, items: const [
                  DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                  DropdownMenuItem(value: 'Kart', child: Text('Kart')),
                  DropdownMenuItem(value: 'Havale', child: Text('Havale')),
                  DropdownMenuItem(value: 'Kampanya', child: Text('Kampanya')),
                ], onChanged: (v) => setState(() => upPayTip = v ?? upPayTip), decoration: const InputDecoration(labelText: 'Tip')),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilledButton(onPressed: () async { try { await _paymentRepo.update(odemeId: selPaymentRow!['ODEME_ID'] as int, tutar: double.tryParse(upPayTutar.text), tur: upPayTur, tipi: upPayTip); _sn('Ödeme güncellendi'); setState(()=>selPaymentRow=null); } catch (e) { _err(e); } }, child: const Text('Kaydet')),
                  OutlinedButton(onPressed: () => setState(()=>selPaymentRow=null), child: const Text('Kapat')),
                ]),
              ]),
            ),
            const Divider(),

            // Cezalar — düzenle/sil/öde
            Text('Cezalar (${fines.length})', style: Theme.of(context).textTheme.titleSmall),
            ...fines.map((f) => ListTile(
              leading: const Icon(Icons.report),
              title: Text('Ceza#${f['CEZA_ID']} • ${f['CEZA_TURU']} • ${(f['CEZA_TUTAR'] ?? '-').toString()} TL'),
              subtitle: Text('${f['CEZA_TARIHI']}'),
              trailing: OverflowBar(spacing: 6, overflowSpacing: 6, children: [
                OutlinedButton(onPressed: () { selFineRow = f; fineTarih.text = (f['CEZA_TARIHI'] ?? '').toString().substring(0,10); fineTur.text = (f['CEZA_TURU'] ?? '').toString(); fineTutar.text = (f['CEZA_TUTAR'] ?? '').toString(); setState((){}); }, child: const Text('Düzenle')),
                OutlinedButton(onPressed: () async { try { await _fineRepo.delete(f['CEZA_ID'] as int); _sn('Ceza silindi'); setState(()=>selFineRow=null); } catch (e) { _err(e); } }, child: const Text('Sil')),
                FilledButton(onPressed: () async { try { final t = (f['CEZA_TUTAR'] as num?)?.toDouble() ?? 0.0; if (t <= 0) { _sn('Ceza tutarı yok'); return; } await _paymentRepo.add(cezaId: f['CEZA_ID'] as int, tutar: t, tur: 'Ceza', tipi: 'Nakit'); _sn('Ceza için ödeme eklendi'); } catch (e) { _err(e); } }, child: const Text('Öde')),
              ]),
            )),
            if (selFineRow != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(spacing: 8, children: [
                FilledButton(onPressed: () async { try { await _fineRepo.update(cezaId: selFineRow!['CEZA_ID'] as int, tarih: DateTime.tryParse(fineTarih.text), tur: fineTur.text.trim().isEmpty ? null : fineTur.text.trim(), tutar: double.tryParse(fineTutar.text)); _sn('Ceza güncellendi'); setState(()=>selFineRow=null); } catch (e) { _err(e); } }, child: const Text('Kaydet')),
                OutlinedButton(onPressed: () => setState(()=>selFineRow=null), child: const Text('Kapat')),
              ]),
            ),
            const Divider(),

            // Sigortalar — düzenle/sil/öde
            Text('Sigortalar (${ins.length})', style: Theme.of(context).textTheme.titleSmall),
            ...ins.map((i) => ListTile(
              leading: Icon(((i['AKTIFMI'] ?? 0) == 1) ? Icons.local_police : Icons.gpp_bad, color: ((i['AKTIFMI'] ?? 0) == 1) ? Colors.green : Colors.orange),
              title: Text('Sig#${i['SIGORTA_ID']} • ${i['SIGORTA_ADI'] ?? '-'} • Maliyet: ${(i['MALIYET'] ?? '-').toString()}'),
              subtitle: Text('Başlangıç: ${i['BASLANGIC_TARIHI']} • Bitiş: ${i['BITIS_TARIHI']}'),
              trailing: OverflowBar(spacing: 6, overflowSpacing: 6, children: [
                OutlinedButton(onPressed: () { selInsRow = i; insAd.text = (i['SIGORTA_ADI'] ?? '').toString(); insKapsam.text = (i['KAPSAM_TURU'] ?? '').toString(); insAciklama.text = (i['KAPSAM_ACIKLAMASI'] ?? '').toString(); insMaliyet.text = (i['MALIYET'] ?? '').toString(); insBas.text = (i['BASLANGIC_TARIHI'] ?? '').toString().substring(0,10); insBit.text = (i['BITIS_TARIHI'] ?? '').toString().substring(0,10); insAktif = ((i['AKTIFMI'] ?? 0) == 1); setState((){}); }, child: const Text('Düzenle')),
                OutlinedButton(onPressed: () async { try { await _insRepo.delete(i['SIGORTA_ID'] as int); _sn('Sigorta silindi'); setState(()=>selInsRow=null); } catch (e) { _err(e); } }, child: const Text('Sil')),
                FilledButton(onPressed: () async { try { final t = (i['MALIYET'] as num?)?.toDouble() ?? 0.0; if (t <= 0) { _sn('Maliyet tutarı yok'); return; } await _paymentRepo.add(sigortaId: i['SIGORTA_ID'] as int, tutar: t, tur: 'Sigorta', tipi: 'Nakit'); _sn('Sigorta için ödeme eklendi'); } catch (e) { _err(e); } }, child: const Text('Öde')),
              ]),
            )),
            if (selInsRow != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(spacing: 8, children: [
                FilledButton(onPressed: () async { try { await _insRepo.update(sigortaId: selInsRow!['SIGORTA_ID'] as int, ad: insAd.text.trim().isEmpty ? null : insAd.text.trim(), kapsamTuru: insKapsam.text.trim().isEmpty ? null : insKapsam.text.trim(), kapsamAciklama: insAciklama.text.trim().isEmpty ? null : insAciklama.text.trim(), maliyet: double.tryParse(insMaliyet.text), baslangic: DateTime.tryParse(insBas.text), bitis: insBit.text.trim().isEmpty ? null : DateTime.tryParse(insBit.text), aktif: insAktif); _sn('Sigorta güncellendi'); setState(()=>selInsRow=null); } catch (e) { _err(e); } }, child: const Text('Kaydet')),
                OutlinedButton(onPressed: () => setState(()=>selInsRow=null), child: const Text('Kapat')),
              ]),
            ),
            const Divider(),

            // Bakım — düzenle/sil/öde
            Text('Bakımlar (${mnts.length})', style: Theme.of(context).textTheme.titleSmall),
            ...mnts.map((b) => ListTile(
              leading: const Icon(Icons.build),
              title: Text('Bakım#${b['BAKIM_ID']} • ${b['BAKIM_TURU'] ?? '-'} • Ücret: ${(b['BAKIM_UCRETI'] ?? '-').toString()}'),
              subtitle: Text('Tarih: ${b['BAKIM_TARIHI']} • Parça: ${((b['PARCA_DEGISTIMI'] ?? 0) == 1) ? 'Evet' : 'Hayır'} • Değişen: ${b['DEGISEN_PARCA'] ?? '-'}'),
              trailing: OverflowBar(spacing: 6, overflowSpacing: 6, children: [
                OutlinedButton(onPressed: () { selMntRow = b; mntTarih.text = (b['BAKIM_TARIHI'] ?? '').toString().substring(0,10); mntTur.text = (b['BAKIM_TURU'] ?? '').toString(); mntUcret.text = (b['BAKIM_UCRETI'] ?? '').toString(); mntParca = ((b['PARCA_DEGISTIMI'] ?? 0) == 1); mntParcaAd.text = (b['DEGISEN_PARCA'] ?? '').toString(); setState((){}); }, child: const Text('Düzenle')),
                OutlinedButton(onPressed: () async { try { await _mntRepo.delete(b['BAKIM_ID'] as int); _sn('Bakım silindi'); setState(()=>selMntRow=null); } catch (e) { _err(e); } }, child: const Text('Sil')),
                FilledButton(onPressed: () async { try { final t = (b['BAKIM_UCRETI'] as num?)?.toDouble() ?? 0.0; if (t <= 0) { _sn('Bakım ücreti yok'); return; } await _paymentRepo.add(bakimId: b['BAKIM_ID'] as int, tutar: t, tur: 'Bakım', tipi: 'Nakit'); _sn('Bakım için ödeme eklendi'); } catch (e) { _err(e); } }, child: const Text('Öde')),
              ]),
            )),
            if (selMntRow != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: mntTarih, decoration: const InputDecoration(labelText: 'Bakım Tarihi (YYYY-MM-DD)')),
                const SizedBox(height: 8),
                TextField(controller: mntTur, decoration: const InputDecoration(labelText: 'Bakım Türü')),
                const SizedBox(height: 8),
                TextField(controller: mntUcret, decoration: const InputDecoration(labelText: 'Ücret (TL)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(children: [ Checkbox(value: mntParca, onChanged: (v) => setState(() => mntParca = v ?? false)), const Text('Parça Değişimi') ]),
                const SizedBox(height: 8),
                TextField(controller: mntParcaAd, decoration: const InputDecoration(labelText: 'Değişen Parça')),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilledButton(onPressed: () async { try { await _mntRepo.update(bakimId: selMntRow!['BAKIM_ID'] as int, tarih: DateTime.tryParse(mntTarih.text), tur: mntTur.text.trim().isEmpty ? null : mntTur.text.trim(), ucret: double.tryParse(mntUcret.text), parcaDegisti: mntParca, degisenParca: mntParcaAd.text.trim().isEmpty ? null : mntParcaAd.text.trim()); _sn('Bakım güncellendi'); setState(()=>selMntRow=null); } catch (e) { _err(e); } }, child: const Text('Kaydet')),
                  OutlinedButton(onPressed: () => setState(()=>selMntRow=null), child: const Text('Kapat')),
                ]),
              ]),
            ),
            const Divider(),

            // Kaza — sil/öde (update seçimi ile form açılıyor)
            Text('Kazalar (${accs.length})', style: Theme.of(context).textTheme.titleSmall),
            ...accs.map((a) => ListTile(
              leading: const Icon(Icons.warning),
              title: Text('Kaza#${a['KAZA_ID']} • ${a['HASAR_TURU'] ?? '-'} • ${(a['HASAR_MIKTARI'] ?? '-').toString()}'),
              subtitle: Text('Tarih: ${a['KAZA_TARIHI']} • Sigorta: ${a['SIGORTA_DURUMU'] ?? '-'}'),
              trailing: OverflowBar(spacing: 6, overflowSpacing: 6, children: [
                OutlinedButton(onPressed: () { selAccRow = a; accTarih.text = (a['KAZA_TARIHI'] ?? '').toString().substring(0,10); accHasarTur.text = (a['HASAR_TURU'] ?? '').toString(); accHasarMiktar.text = (a['HASAR_MIKTARI'] ?? '').toString(); accSigortaDurum.text = (a['SIGORTA_DURUMU'] ?? '').toString(); setState((){}); }, child: const Text('Seç')),
                OutlinedButton(onPressed: () async { try { await _accRepo.delete(a['KAZA_ID'] as int); _sn('Kaza silindi'); setState(()=>selAccRow=null); } catch (e) { _err(e); } }, child: const Text('Sil')),
                FilledButton(onPressed: () async { try { final t = (a['HASAR_MIKTARI'] as num?)?.toDouble() ?? 0.0; if (t <= 0) { _sn('Hasar miktarı yok'); return; } await _paymentRepo.add(kazaId: a['KAZA_ID'] as int, tutar: t, tur: 'Kaza', tipi: 'Nakit'); _sn('Kaza için ödeme eklendi'); } catch (e) { _err(e); } }, child: const Text('Öde')),
              ]),
            )),
            if (selAccRow != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(onPressed: () => setState(()=>selAccRow=null), child: const Text('Kapat')),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedByRez = selRez != null;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _filter,
                      items: const [
                        DropdownMenuItem(value: 'Açık', child: Text('Açık')),
                        DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _filter = v);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _load, child: const Text('Yenile')),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => UiRouter().go(0),
                      icon: const Icon(Icons.home, color: Colors.indigo),
                      label: const Text('Ana Ekran'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Hata: $_error'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final m = _items[i];
                              final selected = _selected?['KIRALAMA_ID'] == m['KIRALAMA_ID'];
                              return Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.key),
                                      title: Text('Kiralama #${m['KIRALAMA_ID']} • ${m['PLAKA']} • ${m['Marka']} ${m['Seri'] ?? ''} ${m['Model']}'),
                                      subtitle: Text(
                                        'Alış: ${m['ALIS_TARIHI']} • Plan Teslim: ${m['PLANLANAN_TESLIM_TARIHI']} • Gerçek Teslim: ${m['GERCEKLESEN_TESLIM_TARIHI'] ?? '-'}',
                                      ),
                                      onTap: () => setState(() => _selected = selected ? null : m),
                                    ),
                                    if (selected) _detailsExpanded(),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kiralama Başlat', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: lockedByRez
                            ? null
                            : () async {
                                final res = await _pickMusteri();
                                if (res != null) setState(() => selMusteri = res);
                              },
                        icon: const Icon(Icons.person_search),
                        label: Text(selMusteri == null ? 'Müşteri Seç' : 'Müşteri seçildi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: lockedByRez
                            ? null
                            : () async {
                                final res = await _pickArac();
                                if (res != null) {
                                  setState(() {
                                    selArac = res;
                                    selGunluk = (res['GUNLUK_KIRA_BEDELI'] as num).toDouble();
                                    selDepo = (res['DEPOZITO_UCRETI'] as num).toDouble();
                                  });
                                }
                              },
                        icon: const Icon(Icons.car_rental),
                        label: Text(selArac == null
                            ? 'Araç Seç'
                            : '${selArac!['Marka']} ${selArac!['Seri'] ?? ''} ${selArac!['Model']} • ${selArac!['PLAKA']}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final r = await _pickRezervasyon();
                          if (r != null) _applyReservation(r);
                        },
                        icon: const Icon(Icons.event_available),
                        label: Text(selRez == null ? 'Rezervasyon (Ops.)' : 'Rez#${selRez!['REZERVASYON_ID']}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final k = await _pickCampaign();
                          if (k != null) setState(() => selCamp = k);
                        },
                        icon: const Icon(Icons.campaign),
                        label: Text(selCamp == null ? 'Kampanya (Ops.)' : '${selCamp!['KAMPANYA_ADI']}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: lockedByRez
                            ? null
                            : () async {
                                final now = DateTime.now().add(const Duration(days: 3));
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: selPlanTeslim ?? now,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) setState(() => selPlanTeslim = d);
                              },
                        icon: const Icon(Icons.date_range),
                        label: Text('Planlanan Teslim: ${selPlanTeslim?.toString().substring(0, 10) ?? '-'}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Alış KM'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => selAlisKm = int.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Günlük Bedel (TL)'),
                        readOnly: true,
                        controller: TextEditingController(text: selGunluk == null ? '' : selGunluk!.toStringAsFixed(2)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Depozito (TL)'),
                        readOnly: true,
                        controller: TextEditingController(text: selDepo == null ? '' : selDepo!.toStringAsFixed(2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _open, icon: const Icon(Icons.play_arrow), label: const Text('Kiralama Başlat')),
                const Divider(height: 24),
                Text('Kiralama Sürecini Bitir', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final s = await _pickSube();
                          if (s != null) {
                            setState(() => selTeslimSube = s);
                            final e = await _pickEmployeeByBranch(s['SUBE_ID'] as int);
                            if (e != null) setState(() => selTeslimCalisan = e);
                          }
                        },
                        icon: const Icon(Icons.home_work),
                        label: Text(selTeslimSube == null ? 'Teslim Şube Seç' : '${selTeslimSube!['SUBE_ADI']}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selTeslimSube == null
                            ? null
                            : () async {
                                final e = await _pickEmployeeByBranch(selTeslimSube!['SUBE_ID'] as int);
                                if (e != null) setState(() => selTeslimCalisan = e);
                              },
                        icon: const Icon(Icons.badge),
                        label: Text(selTeslimCalisan == null ? 'Teslim Çalışan Seç' : 'Çalışan seçildi'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickCloseDate,
                  icon: const Icon(Icons.date_range),
                  label: Text('Gerçek Teslim: ${cGercekTeslim?.toString().substring(0, 10) ?? '-'}'),
                ),
                const SizedBox(height: 8),
                TextField(controller: cDonusKm, decoration: const InputDecoration(labelText: 'Dönüş KM'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: cToplam, decoration: const InputDecoration(labelText: 'Toplam Tutar (Boş: otomatik)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _finishRentalProcess, icon: const Icon(Icons.stop), label: const Text('Kiralama Sürecini Bitir')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}