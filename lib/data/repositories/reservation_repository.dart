import '../db/mssql_service.dart';
import '../../models/session.dart';
import '../../security/acl.dart';
import '../../models/role.dart';
import 'logs_repository.dart';

class ReservationRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listBySube(int subeId, {DateTime? from, DateTime? to, String? q}) async {
    assertPerm(Permission.viewReservations);
    final sess = Session().current!;
    if (sess.subeId != subeId) throw Exception('Sadece kendi şubenizin rezervasyonları');

    final s = q?.replaceAll("'", "''");
    final search = (s == null || s.isEmpty)
        ? ''
        : " AND (CAST(R.REZERVASYON_ID AS VARCHAR(20)) LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%')";

    final f = from == null ? 'NULL' : "'${from.toIso8601String()}'";
    final t = to == null ? 'NULL' : "'${to.toIso8601String()}'";

    return _db.query("""
      SELECT R.*, M.Marka, M.Seri, M.Model, S1.SUBE_ADI AS ALIS_SUBE_ADI, S2.SUBE_ADI AS TESLIM_SUBE_ADI
      FROM dbo.REZERVASYONLAR R
      JOIN dbo.MODEL M ON R.MODEL_ID = M.MODEL_ID
      JOIN dbo.SUBELER S1 ON R.PLANLANAN_ALIS_SUBE_ID = S1.SUBE_ID
      JOIN dbo.SUBELER S2 ON R.PLANLANAN_TESLIM_SUBE_ID = S2.SUBE_ID
      WHERE R.PLANLANAN_ALIS_SUBE_ID = ${sess.subeId}
        AND (${f} IS NULL OR R.PLANLANAN_ALIS_TARIHI >= ${f})
        AND (${t} IS NULL OR R.PLANLANAN_TESLIM_TARIHI <= ${t})
        $search
      ORDER BY R.REZERVASYON_ID DESC
    """);
  }

  Future<List<Map<String, dynamic>>> listServiceableByBranch(int branchId, {String? q}) async {
    assertPerm(Permission.viewReservations);
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " AND (CAST(R.REZERVASYON_ID AS VARCHAR(20)) LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      SELECT R.*, M.Marka, M.Seri, M.Model,
             (SELECT COUNT(*) FROM dbo.ARAC A WHERE A.GUNCEL_SUBE_ID=$branchId AND A.MODEL_ID=R.MODEL_ID AND A.DURUM='Uygun') AS UygunAracSayisi
      FROM dbo.REZERVASYONLAR R
      JOIN dbo.MODEL M ON R.MODEL_ID = M.MODEL_ID
      WHERE R.PLANLANAN_ALIS_SUBE_ID = $branchId
      $filter
      ORDER BY R.REZERVASYON_ID DESC
    """);
  }

  Future<List<Map<String, dynamic>>> listServiceableInOtherBranches(int branchId, {String? q}) async {
    assertPerm(Permission.viewReservations);
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " AND (CAST(R.REZERVASYON_ID AS VARCHAR(20)) LIKE '%$s%' OR M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%')";
    return _db.query("""
      SELECT R.*, M.Marka, M.Seri, M.Model,
             (SELECT TOP 1 S.SUBE_ADI FROM dbo.SUBELER S WHERE S.SUBE_ID IN 
               (SELECT A.GUNCEL_SUBE_ID FROM dbo.ARAC A WHERE A.MODEL_ID=R.MODEL_ID AND A.DURUM='Uygun' AND A.GUNCEL_SUBE_ID <> R.PLANLANAN_ALIS_SUBE_ID)
             ) AS OnerilenSubeAdi,
             (SELECT TOP 1 A.GUNCEL_SUBE_ID FROM dbo.ARAC A WHERE A.MODEL_ID=R.MODEL_ID AND A.DURUM='Uygun' AND A.GUNCEL_SUBE_ID <> R.PLANLANAN_ALIS_SUBE_ID) AS OnerilenSubeId
      FROM dbo.REZERVASYONLAR R
      JOIN dbo.MODEL M ON R.MODEL_ID = M.MODEL_ID
      WHERE R.PLANLANAN_ALIS_SUBE_ID = $branchId
        AND EXISTS (SELECT 1 FROM dbo.ARAC A WHERE A.MODEL_ID=R.MODEL_ID AND A.DURUM='Uygun' AND A.GUNCEL_SUBE_ID <> $branchId)
      $filter
      ORDER BY R.REZERVASYON_ID DESC
    """);
  }

  Future<void> create({
    required int musteriId,
    required int modelId,
    required int alisSubeId,
    required int teslimSubeId,
    required DateTime alis,
    required DateTime teslim,
    int? kampanyaId,
  }) async {
    assertPerm(Permission.editReservations);
    if (teslim.isBefore(alis)) throw Exception('Teslim tarihi alıştan önce olamaz');
    await _db.execute("""
      INSERT INTO dbo.REZERVASYONLAR (MUSTERI_ID, MODEL_ID, PLANLANAN_ALIS_SUBE_ID, PLANLANAN_TESLIM_SUBE_ID,
        PLANLANAN_ALIS_TARIHI, PLANLANAN_TESLIM_TARIHI, KAMPANYA_ID)
      VALUES ($musteriId, $modelId, $alisSubeId, $teslimSubeId, '${alis.toIso8601String()}', '${teslim.toIso8601String()}', ${kampanyaId ?? 'NULL'})
    """);
    final newId = (await _db.query("SELECT MAX(REZERVASYON_ID) AS ID FROM dbo.REZERVASYONLAR")).first['ID'] as int;
    await _logs.add(
      subeId: alisSubeId,
      calisanId: Session().current?.calisanId,
      action: 'Rezervasyon',
      message: 'Rezervasyon eklendi',
      details: {'rezervasyonId': newId, 'musteriId': musteriId, 'modelId': modelId, 'alis': alis.toIso8601String(), 'teslim': teslim.toIso8601String(), 'kampanyaId': kampanyaId},
      relatedType: 'REZERVASYON',
      relatedId: newId,
    );
  }

  Future<void> updateStatus(int rezervasyonId, String durum) async {
    assertPerm(Permission.editReservations);
    final d = durum.replaceAll("'", "''");
    await _db.execute("UPDATE dbo.REZERVASYONLAR SET REZERVASYON_DURUMU='$d' WHERE REZERVASYON_ID=$rezervasyonId");
    final rows = await _db.query("SELECT PLANLANAN_ALIS_SUBE_ID AS SUBE, MODEL_ID, MUSTERI_ID FROM dbo.REZERVASYONLAR WHERE REZERVASYON_ID=$rezervasyonId");
    final subeId = rows.isEmpty ? (Session().current?.subeId ?? 0) : rows.first['SUBE'] as int;
    await _logs.add(
      subeId: subeId,
      calisanId: Session().current?.calisanId,
      action: 'Rezervasyon',
      message: 'Rezervasyon durumu güncellendi: $d',
      details: {'rezervasyonId': rezervasyonId, 'durum': d},
      relatedType: 'REZERVASYON',
      relatedId: rezervasyonId,
    );
  }

  Future<void> delete(int rezervasyonId) async {
    assertPerm(Permission.editReservations);
    final rows = await _db.query("SELECT PLANLANAN_ALIS_SUBE_ID AS SUBE FROM dbo.REZERVASYONLAR WHERE REZERVASYON_ID=$rezervasyonId");
    final subeId = rows.isEmpty ? (Session().current?.subeId ?? 0) : rows.first['SUBE'] as int;
    await _db.execute("DELETE FROM dbo.REZERVASYONLAR WHERE REZERVASYON_ID=$rezervasyonId");
    await _logs.add(
      subeId: subeId,
      calisanId: Session().current?.calisanId,
      action: 'Rezervasyon',
      message: 'Rezervasyon silindi',
      details: {'rezervasyonId': rezervasyonId},
      relatedType: 'REZERVASYON',
      relatedId: rezervasyonId,
    );
  }
}