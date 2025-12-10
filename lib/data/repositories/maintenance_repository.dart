import '../db/mssql_service.dart';
import 'notifications_repository.dart';
import 'logs_repository.dart';

class MaintenanceRepository {
  final _db = MssqlService();
  final _notif = NotificationsRepository();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listBySase(String saseNo) async {
    final s = saseNo.replaceAll("'", "''");
    return _db.query("SELECT * FROM dbo.BAKIM_KAYITLARI WHERE SASE_NO='$s' ORDER BY BAKIM_ID DESC");
  }

  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q, String? saseFilter}) async {
    final s = (q ?? '').replaceAll("'", "''");
    final filterQ = s.isEmpty ? '' : " AND (B.BAKIM_TURU LIKE '%$s%' OR A.PLAKA LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Model LIKE '%$s%')";
    final filterSase = (saseFilter == null || saseFilter.isEmpty)
        ? ''
        : " AND B.SASE_NO = '${saseFilter.replaceAll("'", "''")}'";
    return _db.query("""
      WITH PayStatus AS (
        SELECT BAKIM_ID, COALESCE(SUM(ODEME_TUTARI),0) AS PAID
        FROM dbo.ODEMELER WHERE BAKIM_ID IS NOT NULL
        GROUP BY BAKIM_ID
      )
      SELECT B.*, A.PLAKA, M.Marka, M.Model, A.SASE_NO,
             COALESCE(PS.PAID,0) AS PAID_TOTAL,
             CASE 
               WHEN COALESCE(B.BAKIM_UCRETI,0) = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= COALESCE(B.BAKIM_UCRETI,0) THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END AS PAY_STATUS
      FROM dbo.BAKIM_KAYITLARI B
      JOIN dbo.ARAC A ON B.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      LEFT JOIN PayStatus PS ON PS.BAKIM_ID = B.BAKIM_ID
      WHERE A.GUNCEL_SUBE_ID = $subeId
      $filterSase
      $filterQ
      ORDER BY (CASE WHEN (CASE 
               WHEN COALESCE(B.BAKIM_UCRETI,0) = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= COALESCE(B.BAKIM_UCRETI,0) THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END) IN ('Yok','Kısmi') THEN 0 ELSE 1 END), B.BAKIM_ID DESC
    """);
  }

  Future<void> add({
    required String saseNo,
    required int calisanId,
    required DateTime tarih,
    required String tur,
    double? ucret,
    required bool parcaDegisti,
    String? degisenParca,
  }) async {
    final s = saseNo.replaceAll("'", "''");
    final t = tarih.toIso8601String().substring(0,10);
    final tur2 = tur.replaceAll("'", "''");
    final u = ucret == null ? 'NULL' : ucret.toStringAsFixed(2);
    final pd = parcaDegisti ? 1 : 0;
    final dp = degisenParca == null || degisenParca.trim().isEmpty ? 'NULL' : "'${degisenParca.replaceAll("'", "''")}'";
    await _db.execute("""
      INSERT INTO dbo.BAKIM_KAYITLARI (SASE_NO, CALISAN_ID, BAKIM_TARIHI, BAKIM_TURU, BAKIM_UCRETI, PARCA_DEGISTIMI, DEGISEN_PARCA)
      VALUES ('$s', $calisanId, '$t', '$tur2', $u, $pd, $dp)
    """);
    final sube = await _db.query("SELECT GUNCEL_SUBE_ID FROM dbo.ARAC WHERE SASE_NO='$s'");
    final subeId = sube.isEmpty ? null : sube.first['GUNCEL_SUBE_ID'] as int?;
    if (subeId != null) {
      await _notif.add(
        subeId: subeId,
        category: 'Bakım',
        message: 'Bakım eklendi: $tur2 • $t',
        relatedType: 'BAKIM',
        relatedId: (await _db.query("SELECT MAX(BAKIM_ID) AS ID FROM dbo.BAKIM_KAYITLARI")).first['ID'] as int,
      );
    }
  }

  Future<void> update({
    required int bakimId,
    DateTime? tarih,
    String? tur,
    double? ucret,
    bool? parcaDegisti,
    String? degisenParca,
  }) async {
    final ups = <String>[];
    if (tarih != null) ups.add("BAKIM_TARIHI='${tarih.toIso8601String().substring(0,10)}'");
    if (tur != null) ups.add("BAKIM_TURU='${tur.replaceAll("'", "''")}'");
    if (ucret != null) ups.add("BAKIM_UCRETI=${ucret.toStringAsFixed(2)}");
    if (parcaDegisti != null) ups.add("PARCA_DEGISTIMI=${parcaDegisti?1:0}");
    if (degisenParca != null) ups.add("DEGISEN_PARCA='${degisenParca.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.BAKIM_KAYITLARI SET ${ups.join(', ')} WHERE BAKIM_ID=$bakimId");
  }

  Future<void> delete(int bakimId) async {
    await _db.execute("DELETE FROM dbo.BAKIM_KAYITLARI WHERE BAKIM_ID=$bakimId");
  }
}