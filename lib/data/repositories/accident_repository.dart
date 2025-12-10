import '../db/mssql_service.dart';
import 'logs_repository.dart';
import '../../models/session.dart';

class AccidentRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q}) async {
    final s = (q ?? '').replaceAll("'", "''");
    final filter = s.isEmpty ? '' : " AND (K.HASAR_TURU LIKE '%$s%' OR A.PLAKA LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      WITH PayStatus AS (
        SELECT KAZA_ID, COALESCE(SUM(ODEME_TUTARI),0) AS PAID
        FROM dbo.ODEMELER WHERE KAZA_ID IS NOT NULL
        GROUP BY KAZA_ID
      )
      SELECT K.*, R.KIRALAMA_ID, A.PLAKA, M.Marka, M.Model,
             COALESCE(PS.PAID,0) AS PAID_TOTAL,
             CASE 
               WHEN COALESCE(K.HASAR_MIKTARI,0) = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= COALESCE(K.HASAR_MIKTARI,0) THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END AS PAY_STATUS
      FROM dbo.KAZA_KAYITLARI K
      JOIN dbo.KIRALAMA R ON K.KIRALAMA_ID = R.KIRALAMA_ID
      JOIN dbo.ARAC A ON R.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      LEFT JOIN PayStatus PS ON PS.KAZA_ID = K.KAZA_ID
      WHERE R.ALIS_SUBE_ID = $subeId
      $filter
      ORDER BY (CASE WHEN (CASE 
               WHEN COALESCE(K.HASAR_MIKTARI,0) = 0 THEN 'Yok'
               WHEN COALESCE(PS.PAID,0) >= COALESCE(K.HASAR_MIKTARI,0) THEN 'Ödendi'
               WHEN COALESCE(PS.PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END) IN ('Yok','Kısmi') THEN 0 ELSE 1 END), K.KAZA_ID DESC
    """);
  }

  Future<void> add({
    required int kiralamaId,
    required DateTime tarih,
    required String hasarTuru,
    double? hasarMiktari,
    String? sigortaDurumu,
  }) async {
    final d = tarih.toIso8601String().substring(0,10);
    final ht = hasarTuru.replaceAll("'", "''");
    final hm = hasarMiktari == null ? 'NULL' : hasarMiktari.toStringAsFixed(2);
    final sd = sigortaDurumu == null ? 'NULL' : "'${sigortaDurumu.replaceAll("'", "''")}'";
    await _db.execute("""
      INSERT INTO dbo.KAZA_KAYITLARI (KIRALAMA_ID, KAZA_TARIHI, HASAR_TURU, HASAR_MIKTARI, SIGORTA_DURUMU)
      VALUES ($kiralamaId, '$d', '$ht', $hm, $sd)
    """);

    final subeRows = await _db.query("SELECT ALIS_SUBE_ID FROM dbo.KIRALAMA WHERE KIRALAMA_ID=$kiralamaId");
    final subeId = subeRows.isNotEmpty ? (subeRows.first['ALIS_SUBE_ID'] as int) : Session().current!.subeId;
    final newId = (await _db.query("SELECT MAX(KAZA_ID) AS ID FROM dbo.KAZA_KAYITLARI")).first['ID'] as int;
    await _logs.add(
      subeId: subeId,
      calisanId: Session().current!.calisanId,
      action: 'Kaza',
      message: 'Kaza kaydı eklendi',
      details: {'kazaId': newId, 'kiralamaId': kiralamaId, 'tarih': d, 'hasarTuru': hasarTuru, 'hasarMiktari': hasarMiktari, 'sigortaDurumu': sigortaDurumu},
      relatedType: 'KAZA',
      relatedId: newId,
    );
  }

  Future<void> delete(int kazaId) async {
    // Ödemeler varsa önce silme engeli
    final ref = await _db.query("SELECT COUNT(*) AS C FROM dbo.ODEMELER WHERE KAZA_ID=$kazaId");
    if ((ref.first['C'] as num) > 0) {
      throw Exception('Bu kazaya bağlı ödemeler var. Önce ödemeleri silin.');
    }
    await _db.execute("DELETE FROM dbo.KAZA_KAYITLARI WHERE KAZA_ID=$kazaId");
    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Kaza',
      message: 'Kaza kaydı silindi',
      details: {'kazaId': kazaId},
      relatedType: 'KAZA',
      relatedId: kazaId,
    );
  }
}