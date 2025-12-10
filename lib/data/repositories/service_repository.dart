import '../db/mssql_service.dart';

class ServiceRepository {
  final _db = MssqlService();

  Future<List<Map<String, dynamic>>> listAll({String? q}) async {
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty) ? '' : " WHERE HIZMET_ADI LIKE '%$s%'";
    return _db.query("SELECT * FROM dbo.EK_HIZMETLER$filter ORDER BY HIZMET_ADI");
  }

  // Kiralamaya bağlı ek hizmetleri getir (JOIN ile ad, ücret tipi vs.)
  Future<List<Map<String, dynamic>>> listByRental(int kiralamaId) async {
    return _db.query("""
      SELECT KH.KIRALAMA_ID, KH.HIZMET_ID, KH.ADET, KH.ALINAN_UCRET,
             EH.HIZMET_ADI, EH.UCRET_TIPI, EH.UCRET
      FROM dbo.KIRALAMA_HIZMETLERI KH
      JOIN dbo.EK_HIZMETLER EH ON KH.HIZMET_ID = EH.HIZMET_ID
      WHERE KH.KIRALAMA_ID = $kiralamaId
      ORDER BY EH.HIZMET_ADI
    """);
  }

  // Var olan addServiceToRental ile uyumlu alias — RentalsPage addToRental çağırıyor
  Future<void> addToRental({
    required int kiralamaId,
    required int hizmetId,
    int adet = 1,
    double? ucret,
  }) async {
    await _db.execute("""
      INSERT INTO dbo.KIRALAMA_HIZMETLERI (KIRALAMA_ID, HIZMET_ID, ADET, ALINAN_UCRET)
      VALUES ($kiralamaId, $hizmetId, $adet, ${ucret == null ? 'NULL' : ucret.toStringAsFixed(2)})
    """);
  }

  // Eski ismi koruyorum (referans için)
  Future<void> addServiceToRental({
    required int kiralamaId,
    required int hizmetId,
    int adet = 1,
    double? ucret,
  }) async {
    await addToRental(kiralamaId: kiralamaId, hizmetId: hizmetId, adet: adet, ucret: ucret);
  }

  // Kiralamadaki ek hizmeti güncelle (adet/ucret) — PK (KIRALAMA_ID,HIZMET_ID)
  Future<void> updateInRental({
    required int kiralamaId,
    required int hizmetId,
    int? adet,
    double? ucret,
  }) async {
    final ups = <String>[];
    if (adet != null) ups.add("ADET = $adet");
    if (ucret != null) ups.add("ALINAN_UCRET = ${ucret.toStringAsFixed(2)}");
    if (ups.isEmpty) return;
    await _db.execute("""
      UPDATE dbo.KIRALAMA_HIZMETLERI
      SET ${ups.join(', ')}
      WHERE KIRALAMA_ID = $kiralamaId AND HIZMET_ID = $hizmetId
    """);
  }

  // Kiralamadan ek hizmeti kaldır
  Future<void> removeFromRental({required int kiralamaId, required int hizmetId}) async {
    await _db.execute("""
      DELETE FROM dbo.KIRALAMA_HIZMETLERI
      WHERE KIRALAMA_ID = $kiralamaId AND HIZMET_ID = $hizmetId
    """);
  }

  // EK_HIZMETLER CRUD (ServicesPage kullanıyor)
  Future<void> create({
    required String ad,
    required String ucretTipi,
    required double ucret,
  }) async {
    final a = ad.replaceAll("'", "''");
    final t = ucretTipi.replaceAll("'", "''");
    await _db.execute("""
      INSERT INTO dbo.EK_HIZMETLER (HIZMET_ADI, UCRET_TIPI, UCRET)
      VALUES ('$a', '$t', ${ucret.toStringAsFixed(2)})
    """);
  }

  Future<void> update({
    required int id,
    String? ad,
    String? ucretTipi,
    double? ucret,
  }) async {
    final ups = <String>[];
    if (ad != null) ups.add("HIZMET_ADI='${ad.replaceAll("'", "''")}'");
    if (ucretTipi != null) ups.add("UCRET_TIPI='${ucretTipi.replaceAll("'", "''")}'");
    if (ucret != null) ups.add("UCRET=${ucret.toStringAsFixed(2)}");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.EK_HIZMETLER SET ${ups.join(', ')} WHERE HIZMET_ID=$id");
  }

  Future<void> delete(int id) async {
    // FK: KIRALAMA_HIZMETLERI referansı varsa delete engeli çıkabilir
    // İhtiyaç halinde önce KH satırlarını temizlemek gerekir.
    await _db.execute("DELETE FROM dbo.EK_HIZMETLER WHERE HIZMET_ID=$id");
  }
}