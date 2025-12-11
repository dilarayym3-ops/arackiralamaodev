import '../db/mssql_service.dart';

class NotificationsRepository {
  final _db = MssqlService();

  Future<void> add({
    required int subeId,
    required String category,
    required String message,
    String? relatedType,
    int? relatedId,
  }) async {
    final cat = category.replaceAll("'", "''");
    final msg = message.replaceAll("'", "''");
    final rt = relatedType == null ? 'NULL' : "'${relatedType.replaceAll("'", "''")}'";
    final rid = relatedId == null ? 'NULL' : '$relatedId';
    await _db.execute("""
      INSERT INTO dbo.NOTIFICATIONS (SUBE_ID, CATEGORY, MESSAGE, RELATED_TYPE, RELATED_ID)
      VALUES ($subeId, '$cat', '$msg', $rt, $rid)
    """);
  }

  Future<List<Map<String, dynamic>>> listByBranch(
    int subeId, {
    bool onlyUnread = false,
    String? q,
    String? category,
  }) async {
    final filters = <String>['SUBE_ID = $subeId'];
    if (onlyUnread) filters.add('IS_READ = 0');
    if (q != null && q.trim().isNotEmpty) {
      final s = q.replaceAll("'", "''");
      filters.add("(MESSAGE LIKE '%$s%' OR CATEGORY LIKE '%$s%')");
    }
    if (category != null && category.isNotEmpty && category != 'Tumu') {
      filters.add("CATEGORY = '${category.replaceAll("'", "''")}'");
    }
    final where = filters.join(' AND ');
    return _db.query("""
      SELECT * FROM dbo.NOTIFICATIONS
      WHERE $where
      ORDER BY CREATED_AT DESC, NOTIF_ID DESC
    """);
  }

  Future<void> markRead(int notifId, {bool read = true}) async {
    await _db.execute("UPDATE dbo.NOTIFICATIONS SET IS_READ = ${read ? 1 : 0} WHERE NOTIF_ID = $notifId");
  }

  Future<void> markAllReadByBranch(int subeId) async {
    await _db.execute("UPDATE dbo.NOTIFICATIONS SET IS_READ = 1 WHERE SUBE_ID = $subeId AND IS_READ = 0");
  }

  Future<void> delete(int notifId) async {
    await _db.execute("DELETE FROM dbo.NOTIFICATIONS WHERE NOTIF_ID = $notifId");
  }

  Future<void> deleteAllByBranch(int subeId) async {
    await _db.execute("DELETE FROM dbo.NOTIFICATIONS WHERE SUBE_ID = $subeId");
  }

  Future<void> checkUpcomingRentalDeadlines(int subeId) async {
    final upcoming = await _db.query("""
      SELECT K.KIRALAMA_ID, K.PLANLANAN_TESLIM_TARIHI, A.PLAKA, M.Marka, M.Model,
             DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(K.PLANLANAN_TESLIM_TARIHI AS DATE)) AS GUN_KALDI
      FROM dbo.KIRALAMA K
      JOIN dbo.ARAC A ON K.SASE_NO = A.SASE_NO
      JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      WHERE K.ALIS_SUBE_ID = $subeId
        AND K.GERCEKLESEN_TESLIM_TARIHI IS NULL
        AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(K.PLANLANAN_TESLIM_TARIHI AS DATE)) BETWEEN -7 AND 2
    """);

    for (final r in upcoming) {
      final gunKaldi = (r['GUN_KALDI'] as num).toInt();
      final kiralamaId = r['KIRALAMA_ID'] as int;
      final plaka = r['PLAKA'] ?? '';
      final marka = r['Marka'] ?? '';
      final model = r['Model'] ?? '';

      final existing = await _db.query("""
        SELECT COUNT(*) AS C FROM dbo.NOTIFICATIONS 
        WHERE SUBE_ID = $subeId AND RELATED_TYPE = 'KIRALAMA' AND RELATED_ID = $kiralamaId
          AND CAST(CREATED_AT AS DATE) = CAST(GETDATE() AS DATE)
      """);
      if ((existing.first['C'] as num) > 0) continue;

      String msg;
      String cat = 'Kiralama';
      if (gunKaldi < 0) {
        msg = 'GECIKMIS: Kiralama #$kiralamaId ($plaka - $marka $model) ${-gunKaldi} gün gecikti!';
        cat = 'Uyari';
      } else if (gunKaldi == 0) {
        msg = 'BUGUN TESLIM: Kiralama #$kiralamaId ($plaka - $marka $model) bugün teslim edilmeli!';
        cat = 'Uyari';
      } else {
        msg = 'Yaklasan Teslim: Kiralama #$kiralamaId ($plaka - $marka $model) $gunKaldi gün kaldı';
      }

      await add(subeId: subeId, category: cat, message: msg, relatedType: 'KIRALAMA', relatedId: kiralamaId);
    }
  }

  Future<void> checkUnpaidFines(int subeId) async {
    final unpaid = await _db.query("""
      SELECT C.CEZA_ID, C.CEZA_TUTAR, C.CEZA_TURU, A.PLAKA,
             COALESCE((SELECT SUM(ODEME_TUTARI) FROM dbo.ODEMELER WHERE CEZA_ID = C.CEZA_ID), 0) AS ODENEN
      FROM dbo.CEZA C
      JOIN dbo.KIRALAMA K ON C.KIRALAMA_ID = K.KIRALAMA_ID
      JOIN dbo.ARAC A ON K.SASE_NO = A.SASE_NO
      WHERE K.ALIS_SUBE_ID = $subeId
        AND COALESCE((SELECT SUM(ODEME_TUTARI) FROM dbo.ODEMELER WHERE CEZA_ID = C.CEZA_ID), 0) < C.CEZA_TUTAR
    """);

    for (final c in unpaid) {
      final cezaId = c['CEZA_ID'] as int;
      final tutar = (c['CEZA_TUTAR'] as num).toDouble();
      final odenen = (c['ODENEN'] as num).toDouble();
      final kalan = tutar - odenen;
      final plaka = c['PLAKA'] ?? '';
      final tur = c['CEZA_TURU'] ?? '';

      final existing = await _db.query("""
        SELECT COUNT(*) AS C FROM dbo.NOTIFICATIONS 
        WHERE SUBE_ID = $subeId AND RELATED_TYPE = 'CEZA' AND RELATED_ID = $cezaId
          AND CAST(CREATED_AT AS DATE) = CAST(GETDATE() AS DATE)
      """);
      if ((existing.first['C'] as num) > 0) continue;

      await add(
        subeId: subeId,
        category: 'Odeme',
        message: 'Odenmemis Ceza #$cezaId ($plaka - $tur): Kalan ${kalan.toStringAsFixed(2)} TL',
        relatedType: 'CEZA',
        relatedId: cezaId,
      );
    }
  }

  Future<void> checkUnpaidAccidents(int subeId) async {
    final unpaid = await _db.query("""
      SELECT KZ.KAZA_ID, KZ.HASAR_MIKTARI, KZ.HASAR_TURU, A.PLAKA,
             COALESCE((SELECT SUM(ODEME_TUTARI) FROM dbo.ODEMELER WHERE KAZA_ID = KZ.KAZA_ID), 0) AS ODENEN
      FROM dbo.KAZA_KAYITLARI KZ
      JOIN dbo.KIRALAMA K ON KZ.KIRALAMA_ID = K.KIRALAMA_ID
      JOIN dbo.ARAC A ON K.SASE_NO = A.SASE_NO
      WHERE K.ALIS_SUBE_ID = $subeId
        AND COALESCE(KZ.HASAR_MIKTARI, 0) > 0
        AND COALESCE((SELECT SUM(ODEME_TUTARI) FROM dbo.ODEMELER WHERE KAZA_ID = KZ.KAZA_ID), 0) < COALESCE(KZ.HASAR_MIKTARI, 0)
    """);

    for (final k in unpaid) {
      final kazaId = k['KAZA_ID'] as int;
      final tutar = (k['HASAR_MIKTARI'] as num?)?.toDouble() ?? 0;
      final odenen = (k['ODENEN'] as num).toDouble();
      final kalan = tutar - odenen;
      final plaka = k['PLAKA'] ?? '';
      final tur = k['HASAR_TURU'] ?? '';

      final existing = await _db.query("""
        SELECT COUNT(*) AS C FROM dbo.NOTIFICATIONS 
        WHERE SUBE_ID = $subeId AND RELATED_TYPE = 'KAZA' AND RELATED_ID = $kazaId
          AND CAST(CREATED_AT AS DATE) = CAST(GETDATE() AS DATE)
      """);
      if ((existing.first['C'] as num) > 0) continue;

      await add(
        subeId: subeId,
        category: 'Odeme',
        message: 'Odenmemis Kaza #$kazaId ($plaka - $tur): Kalan ${kalan.toStringAsFixed(2)} TL',
        relatedType: 'KAZA',
        relatedId: kazaId,
      );
    }
  }

  Future<void> addRentalCompletedPaymentNotification({
    required int subeId,
    required int kiralamaId,
    required String plaka,
    required String marka,
    required String model,
    required double toplamTutar,
  }) async {
    await add(
      subeId: subeId,
      category: 'Odeme',
      message: 'Kiralama Tamamlandi #$kiralamaId ($plaka - $marka $model): ${toplamTutar.toStringAsFixed(2)} TL odeme bekleniyor',
      relatedType: 'KIRALAMA',
      relatedId: kiralamaId,
    );
  }

  Future<void> runAllAutoNotifications(int subeId) async {
    await checkUpcomingRentalDeadlines(subeId);
    await checkUnpaidFines(subeId);
    await checkUnpaidAccidents(subeId);
  }
}