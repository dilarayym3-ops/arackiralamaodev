import '../db/mssql_service.dart';
import 'logs_repository.dart';
import '../../models/session.dart';

class FineRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listByRental(int kiralamaId) async {
    return _db.query("SELECT * FROM dbo.CEZA WHERE KIRALAMA_ID=$kiralamaId ORDER BY CEZA_ID DESC");
  }

  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q}) async {
    final s = (q ?? '').replaceAll("'", "''");
    final filter = s.isEmpty ? '' : " AND (C.CEZA_TURU LIKE '%$s%' OR CAST(C.CEZA_ID AS VARCHAR(20)) LIKE '%$s%' OR A.PLAKA LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      WITH PayStatus AS (
        SELECT CEZA_ID, COALESCE(SUM(ODEME_TUTARI),0) AS PAID
        FROM dbo.ODEMELER
        WHERE CEZA_ID IS NOT NULL
        GROUP BY CEZA_ID
      )
      SELECT C.*, R.KIRALAMA_ID, A.PLAKA, M.Marka, M.Model, 
             CASE 
               WHEN COALESCE(PS.PAID,0) >= C.CEZA_TUTAR THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END AS PAY_STATUS,
             COALESCE(PS.PAID,0) AS PAID_TOTAL
      FROM dbo.CEZA C
      JOIN dbo.KIRALAMA R ON C.KIRALAMA_ID = R.KIRALAMA_ID
      JOIN dbo.ARAC A ON R.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      LEFT JOIN PayStatus PS ON PS.CEZA_ID = C.CEZA_ID
      WHERE R.ALIS_SUBE_ID = $subeId
      $filter
      ORDER BY (CASE WHEN (CASE 
               WHEN COALESCE(PS.PAID,0) >= C.CEZA_TUTAR THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok' END) IN ('Yok','Kısmi') THEN 0 ELSE 1 END), C.CEZA_ID DESC
    """);
  }

  Future<List<Map<String, dynamic>>> search({String? q}) async {
    final s = (q ?? '').replaceAll("'", "''");
    final filter = s.isEmpty
        ? ''
        : " WHERE (CAST(CEZA_ID AS VARCHAR(20)) LIKE '%$s%' OR CEZA_TURU LIKE '%$s%' OR CAST(KIRALAMA_ID AS VARCHAR(20)) LIKE '%$s%')";
    return _db.query("SELECT TOP 200 * FROM dbo.CEZA$filter ORDER BY CEZA_ID DESC");
  }

  Future<void> add({required int kiralamaId, required DateTime tarih, required String tur, required double tutar}) async {
    final d = tarih.toIso8601String().substring(0, 10);
    final t = tur.replaceAll("'", "''");
    await _db.execute("""
      INSERT INTO dbo.CEZA (KIRALAMA_ID, CEZA_TARIHI, CEZA_TURU, CEZA_TUTAR)
      VALUES ($kiralamaId, '$d', '$t', ${tutar.toStringAsFixed(2)})
    """);

    final subeRows = await _db.query("SELECT ALIS_SUBE_ID FROM dbo.KIRALAMA WHERE KIRALAMA_ID=$kiralamaId");
    final subeId = subeRows.isNotEmpty ? (subeRows.first['ALIS_SUBE_ID'] as int) : Session().current!.subeId;
    await _logs.add(
      subeId: subeId,
      calisanId: Session().current!.calisanId,
      action: 'Ceza',
      message: 'Ceza eklendi',
      details: {'kiralamaId': kiralamaId, 'tarih': d, 'tur': tur, 'tutar': tutar},
      relatedType: 'CEZA',
      relatedId: (await _db.query("SELECT MAX(CEZA_ID) AS ID FROM dbo.CEZA")).first['ID'] as int,
    );
  }

  Future<void> update({required int cezaId, DateTime? tarih, String? tur, double? tutar}) async {
    final ups = <String>[];
    if (tarih != null) ups.add("CEZA_TARIHI='${tarih.toIso8601String().substring(0,10)}'");
    if (tur != null) ups.add("CEZA_TURU='${tur.replaceAll("'", "''")}'");
    if (tutar != null) ups.add("CEZA_TUTAR=${tutar.toStringAsFixed(2)}");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.CEZA SET ${ups.join(', ')} WHERE CEZA_ID=$cezaId");

    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Ceza',
      message: 'Ceza güncellendi',
      details: {'cezaId': cezaId, 'fields': ups},
      relatedType: 'CEZA',
      relatedId: cezaId,
    );
  }

  Future<void> delete(int cezaId) async {
    final ref = await _db.query("SELECT COUNT(*) AS C FROM dbo.ODEMELER WHERE CEZA_ID=$cezaId");
    if ((ref.first['C'] as num) > 0) {
      throw Exception('Bu cezaya bağlı ödemeler var. Önce ödemeleri silin.');
    }
    await _db.execute("DELETE FROM dbo.CEZA WHERE CEZA_ID=$cezaId");

    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Ceza',
      message: 'Ceza silindi',
      details: {'cezaId': cezaId},
      relatedType: 'CEZA',
      relatedId: cezaId,
    );
  }
}