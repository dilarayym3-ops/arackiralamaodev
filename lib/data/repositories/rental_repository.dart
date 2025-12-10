import '../db/mssql_service.dart';
import '../../models/session.dart';

class RentalRepository {
  final _db = MssqlService();

  Future<List<Map<String, dynamic>>> listBySube(int subeId, {String? durum}) async {
    final sess = Session().current!;
    if (sess.subeId != subeId) throw Exception('Sadece kendi şubenizin kiralamaları');
    final onlyOpen = (durum != null && durum != 'Tümü');
    final filter = onlyOpen ? " AND R.GERCEKLESEN_TESLIM_TARIHI IS NULL" : '';
    return _db.query("""
      SELECT R.*, A.PLAKA, M.Marka, M.Model
      FROM dbo.KIRALAMA R
      JOIN dbo.ARAC A ON R.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      WHERE R.ALIS_SUBE_ID = ${sess.subeId}$filter
      ORDER BY R.KIRALAMA_ID DESC
    """);
  }

  Future<List<Map<String, dynamic>>> search({String? q, int? subeId}) async {
    final sess = Session().current!;
    final sid = subeId ?? sess.subeId;
    final s = (q ?? '').replaceAll("'", "''");
    final filter = s.isEmpty
        ? ''
        : " AND (CAST(R.KIRALAMA_ID AS VARCHAR(20)) LIKE '%$s%' OR A.PLAKA LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      SELECT TOP 200 R.*, A.PLAKA, M.Marka, M.Model
      FROM dbo.KIRALAMA R
      JOIN dbo.ARAC A ON R.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      WHERE R.ALIS_SUBE_ID = $sid
      $filter
      ORDER BY R.KIRALAMA_ID DESC
    """);
  }

  Future<void> open({
    required int musteriId,
    required String saseNo,
    required int alisCalisanId,
    required int alisSubeId,
    required DateTime planlananTeslim,
    required int alisKm,
    required double gunlukBedel,
    required double depozito,
    int? rezervasyonId,
  }) async {
    final pt = planlananTeslim.toIso8601String();
    await _db.execute("""
      INSERT INTO dbo.KIRALAMA (MUSTERI_ID, SASE_NO, ALIS_CALISAN_ID, ALIS_SUBE_ID, REZERVASYON_ID,
        ALIS_TARIHI, PLANLANAN_TESLIM_TARIHI, ALIS_KM, KIRA_GUNLUK_BEDEL, ALINAN_DEPOZITO)
      VALUES ($musteriId, '$saseNo', $alisCalisanId, $alisSubeId, ${rezervasyonId ?? 'NULL'},
        GETDATE(), '$pt', $alisKm, ${gunlukBedel.toStringAsFixed(2)}, ${depozito.toStringAsFixed(2)})
    """);
    await _db.execute("UPDATE dbo.ARAC SET DURUM='Kirada', KM=$alisKm WHERE SASE_NO='$saseNo'");
  }

  Future<void> close({
    required int kiralamaId,
    required int teslimCalisanId,
    required int teslimSubeId,
    required DateTime gercekTeslim,
    required int donusKm,
    required double toplamTutar,
  }) async {
    final gt = gercekTeslim.toIso8601String();
    await _db.execute("""
      UPDATE dbo.KIRALAMA
      SET TESLIM_CALISAN_ID=$teslimCalisanId,
          GERCEKLESEN_TESLIM_SUBE_ID=$teslimSubeId,
          GERCEKLESEN_TESLIM_TARIHI='$gt',
          DONUS_KM=$donusKm,
          TOPLAM_KIRA_TUTARI=${toplamTutar.toStringAsFixed(2)}
      WHERE KIRALAMA_ID=$kiralamaId
    """);
    final rows = await _db.query("SELECT SASE_NO FROM dbo.KIRALAMA WHERE KIRALAMA_ID=$kiralamaId");
    final sase = rows.isEmpty ? null : rows.first['SASE_NO'] as String?;
    if (sase != null) {
      await _db.execute("UPDATE dbo.ARAC SET GUNCEL_SUBE_ID=$teslimSubeId, DURUM='Uygun', KM=$donusKm WHERE SASE_NO='$sase'");
    }
  }

  Future<void> updatePartial({
    required int kiralamaId,
    DateTime? planlananTeslim,
    DateTime? gercekTeslim,
    int? donusKm,
    double? toplamKira,
    int? teslimCalisanId,
    int? teslimSubeId,
    double? gunlukBedel,
    double? depozito,
    String? depozitoDurumu,
  }) async {
    final ups = <String>[];
    if (planlananTeslim != null) ups.add("PLANLANAN_TESLIM_TARIHI='${planlananTeslim.toIso8601String()}'");
    if (gercekTeslim != null) ups.add("GERCEKLESEN_TESLIM_TARIHI='${gercekTeslim.toIso8601String()}'");
    if (donusKm != null) ups.add("DONUS_KM=$donusKm");
    if (toplamKira != null) ups.add("TOPLAM_KIRA_TUTARI=${toplamKira.toStringAsFixed(2)}");
    if (teslimCalisanId != null) ups.add("TESLIM_CALISAN_ID=$teslimCalisanId");
    if (teslimSubeId != null) ups.add("GERCEKLESEN_TESLIM_SUBE_ID=$teslimSubeId");
    if (gunlukBedel != null) ups.add("KIRA_GUNLUK_BEDEL=${gunlukBedel.toStringAsFixed(2)}");
    if (depozito != null) ups.add("ALINAN_DEPOZITO=${depozito.toStringAsFixed(2)}");
    if (depozitoDurumu != null) ups.add("DEPOZITO_DURUMU='${depozitoDurumu.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.KIRALAMA SET ${ups.join(', ')} WHERE KIRALAMA_ID=$kiralamaId");
  }
}