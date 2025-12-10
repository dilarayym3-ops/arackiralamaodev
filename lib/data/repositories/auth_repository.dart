import '../db/mssql_service.dart';
import '../../models/session.dart';
import '../../models/role.dart';

class AuthRepository {
  final _db = MssqlService();

  Future<SessionUser?> loginWithCalisanId({
    required int subeId,
    required int calisanId,
  }) async {
    final rows = await _db.query("""
      SELECT TOP 1 
        C.CALISAN_ID,
        C.SUBE_ID,
        S.SUBE_ADI,
        C.[E-MAIL] AS EMAIL,
        C.AD,
        C.SOYAD,
        C.POZISYON,
        C.DURUM
      FROM dbo.CALISANLAR C
      JOIN dbo.SUBELER S ON S.SUBE_ID = C.SUBE_ID
      WHERE C.SUBE_ID = $subeId
        AND C.CALISAN_ID = $calisanId
        AND (C.DURUM IS NULL OR C.DURUM = 'Aktif')
    """);

    if (rows.isEmpty) return null;
    final r = rows.first;

    final role = Acl.roleFromPozisyon(r['POZISYON'] as String?);
    final perms = Acl.permissions(role);

    return SessionUser(
      calisanId: r['CALISAN_ID'] as int,
      subeId: r['SUBE_ID'] as int,
      subeAdi: r['SUBE_ADI'] ?? '',
      email: r['EMAIL'] ?? '',
      ad: r['AD'] ?? '',
      soyad: r['SOYAD'] ?? '',
      pozisyon: r['POZISYON'],
      role: role,
      perms: perms,
    );
  }
}