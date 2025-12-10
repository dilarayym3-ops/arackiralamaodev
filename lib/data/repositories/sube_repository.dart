import '../db/mssql_service.dart';
import 'logs_repository.dart';
import '../../models/session.dart';

class SubeRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> getAll() async {
    return _db.query("SELECT SUBE_ID, SUBE_ADI, ADRES, TELEFON, IL, ILCE FROM dbo.SUBELER ORDER BY SUBE_ADI");
  }

  Future<Map<String, dynamic>?> getFallbackPhoneForBranch(int subeId) async {
    final rows = await _db.query("SELECT TOP 1 TELEFON FROM dbo.CALISANLAR WHERE SUBE_ID=$subeId AND TELEFON IS NOT NULL AND TELEFON<>'' ORDER BY CALISAN_ID DESC");
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> create({
    required String subeAdi,
    required String adres,
    String? telefon,
    required String il,
    required String ilce,
  }) async {
    final a = subeAdi.replaceAll("'", "''");
    final ad = adres.replaceAll("'", "''");
    final t = telefon?.replaceAll("'", "''");
    final ilS = il.replaceAll("'", "''");
    final ilceS = ilce.replaceAll("'", "''");
    await _db.execute("""
      INSERT INTO dbo.SUBELER (SUBE_ADI, ADRES, TELEFON, IL, ILCE)
      VALUES ('$a', '$ad', ${t == null ? 'NULL' : "'$t'"}, '$ilS', '$ilceS')
    """);
    final newIdRow = await _db.query("SELECT MAX(SUBE_ID) AS ID FROM dbo.SUBELER");
    final newId = newIdRow.first['ID'] as int;
    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Şube',
      message: 'Şube eklendi: $a',
      details: {'subeId': newId, 'adres': adres, 'telefon': telefon, 'il': il, 'ilce': ilce},
      relatedType: 'SUBE',
      relatedId: newId,
    );
  }

  Future<void> update({
    required int subeId,
    String? subeAdi,
    String? adres,
    String? telefon,
    String? il,
    String? ilce,
  }) async {
    final ups = <String>[];
    if (subeAdi != null) ups.add("SUBE_ADI = '${subeAdi.replaceAll("'", "''")}'");
    if (adres != null) ups.add("ADRES = '${adres.replaceAll("'", "''")}'");
    if (telefon != null) ups.add("TELEFON = '${telefon.replaceAll("'", "''")}'");
    if (il != null) ups.add("IL = '${il.replaceAll("'", "''")}'");
    if (ilce != null) ups.add("ILCE = '${ilce.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.SUBELER SET ${ups.join(', ')} WHERE SUBE_ID = $subeId");
    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Şube',
      message: 'Şube güncellendi',
      details: {'subeId': subeId, 'fields': ups},
      relatedType: 'SUBE',
      relatedId: subeId,
    );
  }

  Future<void> delete(int subeId) async {
    final rows = await _db.query("""
      SELECT 
        (SELECT COUNT(*) FROM dbo.ARAC WHERE GUNCEL_SUBE_ID = $subeId) AS AracCount,
        (SELECT COUNT(*) FROM dbo.CALISANLAR WHERE SUBE_ID = $subeId) AS CalisanCount
    """);
    final r = rows.first;
    if ((r['AracCount'] as num) > 0 || (r['CalisanCount'] as num) > 0) {
      throw Exception('Şubede bağlı araç/çalışan mevcut, silinemez.');
    }
    await _db.execute("DELETE FROM dbo.SUBELER WHERE SUBE_ID = $subeId");
    await _logs.add(
      subeId: Session().current!.subeId,
      calisanId: Session().current!.calisanId,
      action: 'Şube',
      message: 'Şube silindi',
      details: {'subeId': subeId},
      relatedType: 'SUBE',
      relatedId: subeId,
    );
  }
}