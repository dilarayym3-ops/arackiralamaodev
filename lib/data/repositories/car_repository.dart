import '../db/mssql_service.dart';
import '../../models/session.dart';
import '../../security/acl.dart';
import '../../models/role.dart';
import 'logs_repository.dart';

class CarRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  String _sq(String? s) {
    if (s == null) return 'NULL';
    final v = s.replaceAll("'", "''");
    return "'$v'";
  }

  Future<List<Map<String, dynamic>>> listDetailedBySube({
    required int subeId,
    String? q,
    int page = 1,
    int pageSize = 100,
  }) async {
    assertPerm(Permission.viewVehicles);
    final sess = Session().current!;
    if (sess.subeId != subeId) throw Exception('Sadece kendi şubenizin araçları');

    final safeQ = q?.replaceAll("'", "''");
    final filter = (safeQ == null || safeQ.isEmpty)
        ? ''
        : " AND (M.Marka LIKE '%$safeQ%' OR M.Seri LIKE '%$safeQ%' OR M.Model LIKE '%$safeQ%' OR A.PLAKA LIKE '%$safeQ%')";
    final offset = (page - 1) * pageSize;

    return _db.query("""
      SELECT
        A.SASE_NO, A.PLAKA, A.DURUM, A.KM, A.RENK, A.GUNCEL_SUBE_ID,
        M.MODEL_ID, M.Marka, M.Seri, M.Model, M.Yil,
        M.Yakit_Tipi, M.Vites, M.Sanziman, M.Kasa_Tipi, M.Kapi_Sayisi, M.Koltuk_Sayisi,
        M.Yakit_Tuketimi_SI, M.Yakit_Tuketimi_SD, M.Yakit_Depo_Hacmi, M.Motor_Gucu, M.Motor_Hacmi, M.Segment,
        M.Azami_Surat, M.Uzunluk, M.Genislik, M.Yukseklik, M.Agirlik, M.Bagaj_Hacmi,
        M.GUNLUK_KIRA_BEDELI, M.DEPOZITO_UCRETI
      FROM dbo.ARAC A
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      WHERE A.GUNCEL_SUBE_ID = ${sess.subeId}
      $filter
      ORDER BY M.Marka, M.Model, A.PLAKA
      OFFSET $offset ROWS FETCH NEXT $pageSize ROWS ONLY
    """);
  }

  Future<List<Map<String, dynamic>>> listAllCarsServerWide({String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " WHERE (M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%' OR A.PLAKA LIKE '%$s%')";
    return _db.query("""
      SELECT
        A.SASE_NO, A.PLAKA, A.DURUM, A.KM, A.RENK,
        A.GUNCEL_SUBE_ID,
        M.MODEL_ID, M.Marka, M.Seri, M.Model, M.Yil,
        M.GUNLUK_KIRA_BEDELI, M.DEPOZITO_UCRETI
      FROM dbo.ARAC A
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      $filter
      ORDER BY M.Marka, M.Model, A.PLAKA
    """);
  }

  Future<void> create({
    required String saseNo,
    required String plaka,
    required int modelId,
    required int subeId,
    required int km,
    String durum = 'Uygun',
    String? renk,
  }) async {
    assertPerm(Permission.editVehicles);
    final escSase = saseNo.replaceAll("'", "''");
    final escPlaka = plaka.replaceAll("'", "''");
    final escDurum = durum.replaceAll("'", "''");
    final escRenk = renk?.replaceAll("'", "''");

    final modelRows = await _db.query("SELECT MODEL_ID FROM dbo.MODEL WHERE MODEL_ID=$modelId");
    if (modelRows.isEmpty) throw Exception('Model bulunamadı');

    final subeRows = await _db.query("SELECT SUBE_ID FROM dbo.SUBELER WHERE SUBE_ID=$subeId");
    if (subeRows.isEmpty) throw Exception('Şube bulunamadı');

    final exists = await _db.query("SELECT COUNT(*) AS C FROM dbo.ARAC WHERE SASE_NO='$escSase' OR PLAKA='$escPlaka'");
    if ((exists.first['C'] as num) > 0) throw Exception('Şase veya plaka zaten kayıtlı');

    await _db.execute("""
      INSERT INTO dbo.ARAC (SASE_NO, MODEL_ID, GUNCEL_SUBE_ID, PLAKA, KM, DURUM, RENK)
      VALUES ('$escSase', $modelId, $subeId, '$escPlaka', $km, '$escDurum', ${escRenk == null ? 'NULL' : "'$escRenk'"} )
    """);

    await _logs.add(
      subeId: subeId,
      calisanId: Session().current?.calisanId,
      action: 'Araç',
      message: 'Yeni araç eklendi: $escPlaka • model#$modelId',
      details: {'saseNo': escSase, 'plaka': escPlaka, 'modelId': modelId, 'subeId': subeId, 'km': km, 'durum': durum, 'renk': renk},
      relatedType: 'ARAC',
      relatedId: null,
    );
  }

  Future<void> update({
    required String saseNo,
    int? modelId,
    int? subeId,
    String? plaka,
    int? km,
    String? durum,
    String? renk,
  }) async {
    assertPerm(Permission.editVehicles);
    final ups = <String>[];
    if (modelId != null) ups.add('MODEL_ID = $modelId');
    if (subeId != null) { assertPerm(Permission.editBranches); ups.add('GUNCEL_SUBE_ID = $subeId'); }
    if (plaka != null) ups.add('PLAKA = ${_sq(plaka)}');
    if (km != null) ups.add('KM = $km');
    if (durum != null) ups.add('DURUM = ${_sq(durum)}');
    if (renk != null) ups.add('RENK = ${_sq(renk)}');
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.ARAC SET ${ups.join(', ')} WHERE SASE_NO = ${_sq(saseNo)}");

    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Araç',
      message: 'Araç güncellendi',
      details: {'saseNo': saseNo, 'fields': ups},
      relatedType: 'ARAC',
      relatedId: null,
    );
  }

  Future<void> transferToBranch({required String saseNo, required int targetSubeId}) async {
    assertPerm(Permission.editVehicles);
    final escSase = saseNo.replaceAll("'", "''");
    final open = await _db.query("SELECT COUNT(*) AS C FROM dbo.KIRALAMA WHERE SASE_NO='$escSase' AND GERCEKLESEN_TESLIM_TARIHI IS NULL");
    if ((open.first['C'] as num) > 0) throw Exception('Araç kirada, transfer edilemez');
    await _db.execute("UPDATE dbo.ARAC SET GUNCEL_SUBE_ID=$targetSubeId, DURUM='Uygun' WHERE SASE_NO='$escSase'");

    await _logs.add(
      subeId: targetSubeId,
      calisanId: Session().current!.calisanId,
      action: 'Araç',
      message: 'Araç transfer edildi',
      details: {'saseNo': escSase, 'targetSubeId': targetSubeId},
      relatedType: 'ARAC',
      relatedId: null,
    );
  }
}