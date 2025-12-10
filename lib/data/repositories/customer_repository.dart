import '../db/mssql_service.dart';
import 'logs_repository.dart';

class CustomerRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listAll({String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " WHERE AD LIKE '%$s%' OR SOYAD LIKE '%$s%' OR [E-MAIL] LIKE '%$s%' OR TC_NO LIKE '%$s%'";
    return _db.query("SELECT * FROM dbo.MUSTERILER$filter ORDER BY MUSTERI_ID DESC");
  }

  Future<void> create({
    required String tc,
    required String ehliyet,
    required String ad,
    required String soyad,
    required String tel,
    required String email,
    String? adres,
  }) async {
    await _db.execute("""
      INSERT INTO dbo.MUSTERILER (TC_NO, EHLIYET_ID, AD, SOYAD, TELEFON, [E-MAIL], ADRES)
      VALUES ('${tc.replaceAll("'", "''")}', '${ehliyet.replaceAll("'", "''")}',
              '${ad.replaceAll("'", "''")}', '${soyad.replaceAll("'", "''")}',
              '${tel.replaceAll("'", "''")}', '${email.replaceAll("'", "''")}',
              ${adres == null ? 'NULL' : "'${adres.replaceAll("'", "''")}'"})
    """);
  }

  Future<void> update({
    required int id,
    String? tel,
    String? email,
    String? adres,
    String? durum,
  }) async {
    final ups = <String>[];
    if (tel != null) ups.add("TELEFON='${tel.replaceAll("'", "''")}'");
    if (email != null) ups.add("[E-MAIL]='${email.replaceAll("'", "''")}'");
    if (adres != null) ups.add("ADRES='${adres.replaceAll("'", "''")}'");
    if (durum != null) ups.add("DURUM='${durum.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.MUSTERILER SET ${ups.join(', ')} WHERE MUSTERI_ID=$id");
  }

  Future<void> deleteSoft(int id) async {
    await _db.execute("UPDATE dbo.MUSTERILER SET DURUM='Silindi' WHERE MUSTERI_ID=$id");
  }
}