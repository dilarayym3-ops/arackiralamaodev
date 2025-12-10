import '../db/mssql_service.dart';

class ModelRepository {
  final _db = MssqlService();

  // Mevcut: Tüm modeller (global)
  Future<List<Map<String, dynamic>>> listAll({String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " WHERE (Marka LIKE '%$s%' OR Seri LIKE '%$s%' OR Model LIKE '%$s%' OR CAST(MODEL_ID AS VARCHAR(20)) LIKE '%$s%')";
    return _db.query("""
      SELECT MODEL_ID, Marka, Seri, Model, Yil,
             Yakit_Tipi, Vites, Sanziman, Kasa_Tipi, Kapi_Sayisi, Koltuk_Sayisi,
             Yakit_Tuketimi_SI, Yakit_Tuketimi_SD, Yakit_Depo_Hacmi, Motor_Gucu, Motor_Hacmi, Segment,
             Azami_Surat, Uzunluk, Genislik, Yukseklik, Agirlik, Bagaj_Hacmi,
             GUNLUK_KIRA_BEDELI, DEPOZITO_UCRETI
      FROM dbo.MODEL
      $filter
      ORDER BY Marka, Model, Yil DESC
    """);
  }

  // YENI: Sadece ilgili şubede Uygun durumda aracı olan modeller (distinct)
  Future<List<Map<String, dynamic>>> listAvailableInBranch(int subeId, {String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " AND (M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%' OR CAST(M.MODEL_ID AS VARCHAR(20)) LIKE '%$s%')";
    return _db.query("""
      SELECT DISTINCT
        M.MODEL_ID, M.Marka, M.Seri, M.Model, M.Yil,
        M.Yakit_Tipi, M.Vites,
        M.GUNLUK_KIRA_BEDELI, M.DEPOZITO_UCRETI
      FROM dbo.MODEL M
      JOIN dbo.ARAC A ON A.MODEL_ID = M.MODEL_ID
      WHERE A.GUNCEL_SUBE_ID = $subeId
        AND A.DURUM = 'Uygun'
      $filter
      ORDER BY M.Marka, M.Model, M.Yil DESC
    """);
  }

  // YENI: Diğer şubelerde Uygun durumda aracı olan modeller (şube bilgisi ile)
  Future<List<Map<String, dynamic>>> listAvailableInOtherBranches(int mySubeId, {String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty)
        ? ''
        : " AND (M.Marka LIKE '%$s%' OR M.Seri LIKE '%$s%' OR M.Model LIKE '%$s%' OR CAST(M.MODEL_ID AS VARCHAR(20)) LIKE '%$s%')";
    return _db.query("""
      SELECT DISTINCT
        M.MODEL_ID, M.Marka, M.Seri, M.Model, M.Yil,
        M.GUNLUK_KIRA_BEDELI, M.DEPOZITO_UCRETI,
        S.SUBE_ID, S.SUBE_ADI
      FROM dbo.MODEL M
      JOIN dbo.ARAC A ON A.MODEL_ID = M.MODEL_ID
      JOIN dbo.SUBELER S ON S.SUBE_ID = A.GUNCEL_SUBE_ID
      WHERE A.GUNCEL_SUBE_ID <> $mySubeId
        AND A.DURUM = 'Uygun'
      $filter
      ORDER BY M.Marka, M.Model, M.Yil DESC, S.SUBE_ADI
    """);
  }

  Future<void> updatePricing({
    required int modelId,
    required double gunluk,
    required double depozito,
  }) async {
    await _db.execute("""
      UPDATE dbo.MODEL
      SET GUNLUK_KIRA_BEDELI=${gunluk.toStringAsFixed(2)},
          DEPOZITO_UCRETI=${depozito.toStringAsFixed(2)}
      WHERE MODEL_ID=$modelId
    """);
  }

  Future<void> updateTechnicalAndPricing({
    required int modelId,
    Map<String, dynamic>? fields,
  }) async {
    if (fields == null || fields.isEmpty) return;
    final ups = <String>[];
    fields.forEach((k, v) {
      if (v == null) return;
      if (v is String) {
        final esc = v.replaceAll("'", "''");
        ups.add("$k = '$esc'");
      } else if (v is num) {
        ups.add("$k = ${v.toString()}");
      } else {
        ups.add("$k = NULL");
      }
    });
    await _db.execute("UPDATE dbo.MODEL SET ${ups.join(', ')} WHERE MODEL_ID=$modelId");
  }
}