import '../db/mssql_service.dart';

class EmployeeRepository {
  final _db = MssqlService();

  Future<List<Map<String, dynamic>>> listBySube(int subeId, {String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " AND (AD LIKE '%$s%' OR SOYAD LIKE '%$s%' OR [E-MAIL] LIKE '%$s%' OR TC_NO LIKE '%$s%')";
    return _db.query("""
      SELECT CALISAN_ID, SUBE_ID, AD, SOYAD, [E-MAIL], TELEFON, POZISYON, DURUM
      FROM dbo.CALISANLAR
      WHERE SUBE_ID = $subeId
      $filter
      ORDER BY AD, SOYAD
    """);
  }

  Future<void> create({
    required int subeId,
    required String tc,
    required String email,
    required String ad,
    required String soyad,
    String? telefon,
    String? pozisyon,
    String? durum,
  }) async {
    await _db.execute("""
      INSERT INTO dbo.CALISANLAR (SUBE_ID, TC_NO, [E-MAIL], AD, SOYAD, TELEFON, POZISYON, DURUM)
      VALUES ($subeId, '${tc.replaceAll("'", "''")}', '${email.replaceAll("'", "''")}',
              '${ad.replaceAll("'", "''")}', '${soyad.replaceAll("'", "''")}',
              ${telefon == null ? 'NULL' : "'${telefon.replaceAll("'", "''")}'"},
              ${pozisyon == null ? 'NULL' : "'${pozisyon.replaceAll("'", "''")}'"},
              ${durum == null ? 'NULL' : "'${durum.replaceAll("'", "''")}'"})
    """);
  }

  Future<void> update({
    required int calisanId,
    String? telefon,
    String? pozisyon,
    String? durum,
    String? email,
  }) async {
    final ups = <String>[];
    if (telefon != null) ups.add("TELEFON = '${telefon.replaceAll("'", "''")}'");
    if (pozisyon != null) ups.add("POZISYON = '${pozisyon.replaceAll("'", "''")}'");
    if (durum != null) ups.add("DURUM = '${durum.replaceAll("'", "''")}'");
    if (email != null) ups.add("[E-MAIL] = '${email.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.CALISANLAR SET ${ups.join(', ')} WHERE CALISAN_ID = $calisanId");
  }

  Future<void> delete(int calisanId) async {
    // FK kontrol: KIRALAMA referansları varsa silme, sadece DURUM='Pasif' yap
    final ref = await _db.query("SELECT COUNT(*) AS C FROM dbo.KIRALAMA WHERE ALIS_CALISAN_ID = $calisanId OR TESLIM_CALISAN_ID = $calisanId");
    if ((ref.first['C'] as num) > 0) {
      await _db.execute("UPDATE dbo.CALISANLAR SET DURUM='Pasif' WHERE CALISAN_ID=$calisanId");
    } else {
      await _db.execute("DELETE FROM dbo.CALISANLAR WHERE CALISAN_ID=$calisanId");
    }
  }
}