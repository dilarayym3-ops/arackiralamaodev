import '../db/mssql_service.dart';
import 'logs_repository.dart';
import '../../models/session.dart';

class CampaignRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<void> _refreshStatuses() async {
    await _db.execute("""
      UPDATE dbo.KAMPANYALAR
      SET AKTIF_MI = CASE 
        WHEN (BASLANGIC_TARIHI IS NULL OR BASLANGIC_TARIHI <= CAST(GETDATE() AS DATE))
         AND (BITIS_TARIHI IS NULL OR BITIS_TARIHI >= CAST(GETDATE() AS DATE))
        THEN 1 ELSE 0 END
    """);
  }

  Future<List<Map<String, dynamic>>> listAll({String? q}) async {
    await _refreshStatuses();
    final s = q?.replaceAll("'", "''");
    final filter = (s == null || s.isEmpty) ? '' : " WHERE KAMPANYA_ADI LIKE '%$s%'";
    return _db.query("SELECT * FROM dbo.KAMPANYALAR$filter ORDER BY AKTIF_MI DESC, BASLANGIC_TARIHI DESC");
  }

  Future<void> create({
    required String ad,
    DateTime? baslangic,
    DateTime? bitis,
    double? indirimOrani,
    String? kosullar,
  }) async {
    final a = ad.replaceAll("'", "''");
    final bas = baslangic == null ? 'NULL' : "'${baslangic.toIso8601String().substring(0, 10)}'";
    final bit = bitis == null ? 'NULL' : "'${bitis.toIso8601String().substring(0, 10)}'";
    final ind = indirimOrani == null ? 'NULL' : indirimOrani.toStringAsFixed(2);
    final kos = kosullar == null ? 'NULL' : "'${kosullar.replaceAll("'", "''")}'";
    await _db.execute("""
      INSERT INTO dbo.KAMPANYALAR (KAMPANYA_ADI, BASLANGIC_TARIHI, BITIS_TARIHI, INDIRIM_ORANI, KOSULLAR, AKTIF_MI)
      VALUES ('$a', $bas, $bit, $ind, $kos, 1)
    """);
    final id = (await _db.query("SELECT MAX(KAMPANYA_ID) AS ID FROM dbo.KAMPANYALAR")).first['ID'] as int;
    await _logs.add(
      subeId: Session().current?.subeId ?? 0,
      calisanId: Session().current?.calisanId,
      action: 'Kampanya',
      message: 'Kampanya eklendi: $ad',
      details: {'kampanyaId': id, 'baslangic': baslangic?.toString(), 'bitis': bitis?.toString(), 'indirimOrani': indirimOrani, 'kosullar': kosullar},
      relatedType: 'KAMPANYA',
      relatedId: id,
    );
  }

  Future<void> update({
    required int kampanyaId,
    String? ad,
    DateTime? baslangic,
    DateTime? bitis,
    double? indirimOrani,
    String? kosullar,
    bool? aktif,
  }) async {
    final ups = <String>[];
    if (ad != null) ups.add("KAMPANYA_ADI='${ad.replaceAll("'", "''")}'");
    if (baslangic != null) ups.add("BASLANGIC_TARIHI='${baslangic.toIso8601String().substring(0, 10)}'");
    if (bitis != null) ups.add("BITIS_TARIHI='${bitis.toIso8601String().substring(0, 10)}'");
    if (indirimOrani != null) ups.add("INDIRIM_ORANI=${indirimOrani.toStringAsFixed(2)}");
    if (kosullar != null) ups.add("KOSULLAR='${kosullar.replaceAll("'", "''")}'");
    if (aktif != null) ups.add("AKTIF_MI=${aktif ? 1 : 0}");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.KAMPANYALAR SET ${ups.join(', ')} WHERE KAMPANYA_ID=$kampanyaId");
    await _refreshStatuses();
    await _logs.add(
      subeId: Session().current?.subeId ?? 0,
      calisanId: Session().current?.calisanId,
      action: 'Kampanya',
      message: 'Kampanya güncellendi',
      details: {'kampanyaId': kampanyaId, 'fields': ups},
      relatedType: 'KAMPANYA',
      relatedId: kampanyaId,
    );
  }

  Future<void> delete(int kampanyaId) async {
    await _db.execute("DELETE FROM dbo.KAMPANYALAR WHERE KAMPANYA_ID=$kampanyaId");
    await _logs.add(
      subeId: Session().current?.subeId ?? 0,
      calisanId: Session().current?.calisanId,
      action: 'Kampanya',
      message: 'Kampanya silindi',
      details: {'kampanyaId': kampanyaId},
      relatedType: 'KAMPANYA',
      relatedId: kampanyaId,
    );
  }
}