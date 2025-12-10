import '../db/mssql_service.dart';
import 'notifications_repository.dart';

class InsuranceRepository {
  final _db = MssqlService();
  final _notif = NotificationsRepository();

  Future<List<Map<String, dynamic>>> listBySase(String saseNo) async {
    final s = saseNo.replaceAll("'", "''");
    return _db.query("SELECT * FROM dbo.SIGORTA WHERE SASE_NO='$s' ORDER BY SIGORTA_ID DESC");
  }

  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q}) async {
    final s = (q ?? '').replaceAll("'", "''");
    final filter = s.isEmpty ? '' : " AND (I.SIGORTA_ADI LIKE '%$s%' OR A.PLAKA LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      WITH PayStatus AS (
        SELECT SIGORTA_ID, COALESCE(SUM(ODEME_TUTARI),0) AS PAID
        FROM dbo.ODEMELER WHERE SIGORTA_ID IS NOT NULL
        GROUP BY SIGORTA_ID
      )
      SELECT I.*, A.PLAKA, M.Marka, M.Model, A.SASE_NO,
             COALESCE(PS.PAID,0) AS PAID_TOTAL,
             CASE 
               WHEN I.MALIYET IS NULL OR I.MALIYET = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= I.MALIYET THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END AS PAY_STATUS
      FROM dbo.SIGORTA I
      JOIN dbo.ARAC A ON I.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      LEFT JOIN PayStatus PS ON PS.SIGORTA_ID = I.SIGORTA_ID
      WHERE A.GUNCEL_SUBE_ID = $subeId
      $filter
      ORDER BY (CASE WHEN (CASE 
               WHEN I.MALIYET IS NULL OR I.MALIYET = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= I.MALIYET THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END) IN ('Yok','Kısmi') THEN 0 ELSE 1 END), I.SIGORTA_ID DESC
    """);
  }

  Future<void> add({
    required String saseNo,
    String? ad,
    String? kapsamTuru,
    String? kapsamAciklama,
    double? maliyet,
    DateTime? baslangic,
    DateTime? bitis,
    required bool aktif,
  }) async {
    final s = saseNo.replaceAll("'", "''");
    final ad2 = ad == null ? 'NULL' : "'${ad.replaceAll("'", "''")}'";
    final kt = kapsamTuru == null ? 'NULL' : "'${kapsamTuru.replaceAll("'", "''")}'";
    final ka = kapsamAciklama == null ? 'NULL' : "'${kapsamAciklama.replaceAll("'", "''")}'";
    final m = maliyet == null ? 'NULL' : maliyet.toStringAsFixed(2);
    final b1 = baslangic == null ? 'NULL' : "'${baslangic.toIso8601String().substring(0,10)}'";
    final b2 = bitis == null ? 'NULL' : "'${bitis.toIso8601String().substring(0,10)}'";
    final ak = aktif ? 1 : 0;
    await _db.execute("""
      INSERT INTO dbo.SIGORTA (SASE_NO, SIGORTA_ADI, KAPSAM_TURU, KAPSAM_ACIKLAMASI, MALIYET, BASLANGIC_TARIHI, BITIS_TARIHI, AKTIFMI)
      VALUES ('$s', $ad2, $kt, $ka, $m, $b1, $b2, $ak)
    """);
    final sube = await _db.query("SELECT GUNCEL_SUBE_ID FROM dbo.ARAC WHERE SASE_NO='$s'");
    final subeId = sube.isEmpty ? null : sube.first['GUNCEL_SUBE_ID'] as int?;
    if (subeId != null) {
      await _notif.add(
        subeId: subeId,
        category: 'Sigorta',
        message: 'Sigorta eklendi: ${ad ?? '-'}',
        relatedType: 'SIGORTA',
        relatedId: (await _db.query("SELECT MAX(SIGORTA_ID) AS ID FROM dbo.SIGORTA")).first['ID'] as int,
      );
    }
  }

  Future<void> update({
    required int sigortaId,
    String? ad,
    String? kapsamTuru,
    String? kapsamAciklama,
    double? maliyet,
    DateTime? baslangic,
    DateTime? bitis,
    bool? aktif,
  }) async {
    final ups = <String>[];
    if (ad != null) ups.add("SIGORTA_ADI='${ad.replaceAll("'", "''")}'");
    if (kapsamTuru != null) ups.add("KAPSAM_TURU='${kapsamTuru.replaceAll("'", "''")}'");
    if (kapsamAciklama != null) ups.add("KAPSAM_ACIKLAMASI='${kapsamAciklama.replaceAll("'", "''")}'");
    if (maliyet != null) ups.add("MALIYET=${maliyet.toStringAsFixed(2)}");
    if (baslangic != null) ups.add("BASLANGIC_TARIHI='${baslangic.toIso8601String().substring(0,10)}'");
    if (bitis != null) ups.add("BITIS_TARIHI='${bitis.toIso8601String().substring(0,10)}'");
    if (aktif != null) ups.add("AKTIFMI=${aktif?1:0}");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.SIGORTA SET ${ups.join(', ')} WHERE SIGORTA_ID=$sigortaId");
  }

  Future<void> delete(int sigortaId) async {
    await _db.execute("DELETE FROM dbo.SIGORTA WHERE SIGORTA_ID=$sigortaId");
  }
}