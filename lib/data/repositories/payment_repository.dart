import '../db/mssql_service.dart';
import 'logs_repository.dart';

class PaymentRepository {
  final _db = MssqlService();
  final _logs = LogsRepository();

  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q}) async {
    final s = (q ?? '').replaceAll("'", "''");

    // Ödeme durumunu hesapla: Ceza/Sigorta/Bakım/Kaza için ilgili toplam tutar ile ödenen toplamı karşılaştır
    // Sıralama: önce ödenmemiş (Yok/Kısmi), sonra Ödendi
    final filter = s.isEmpty ? '' : """
      AND (
        CAST(P.ODEME_ID AS VARCHAR(20)) LIKE '%$s%' OR
        A.PLAKA LIKE '%$s%' OR
        M.Marka LIKE '%$s%' OR
        M.Model LIKE '%$s%' OR
        P.ODEME_TURU LIKE '%$s%' OR
        P.ODEME_TIPI LIKE '%$s%' OR
        I.SIGORTA_ADI LIKE '%$s%' OR
        B.BAKIM_TURU LIKE '%$s%' OR
        K.HASAR_TURU LIKE '%$s%'
      )
    """;
    return _db.query("""
      WITH PayAgg AS (
        SELECT 
          P.ODEME_ID, P.KIRALAMA_ID, P.CEZA_ID, P.SIGORTA_ID, P.BAKIM_ID, P.KAZA_ID, P.ODEME_TUTARI,
          CASE 
            WHEN P.CEZA_ID IS NOT NULL THEN (SELECT CEZA_TUTAR FROM dbo.CEZA WHERE CEZA_ID = P.CEZA_ID)
            WHEN P.SIGORTA_ID IS NOT NULL THEN (SELECT COALESCE(MALIYET,0) FROM dbo.SIGORTA WHERE SIGORTA_ID = P.SIGORTA_ID)
            WHEN P.BAKIM_ID IS NOT NULL THEN (SELECT COALESCE(BAKIM_UCRETI,0) FROM dbo.BAKIM_KAYITLARI WHERE BAKIM_ID = P.BAKIM_ID)
            WHEN P.KAZA_ID IS NOT NULL THEN (SELECT COALESCE(HASAR_MIKTARI,0) FROM dbo.KAZA_KAYITLARI WHERE KAZA_ID = P.KAZA_ID)
            ELSE NULL
          END AS TOTAL_TARGET,
          CASE 
            WHEN P.CEZA_ID IS NOT NULL THEN (SELECT COALESCE(SUM(ODEME_TUTARI),0) FROM dbo.ODEMELER WHERE CEZA_ID = P.CEZA_ID)
            WHEN P.SIGORTA_ID IS NOT NULL THEN (SELECT COALESCE(SUM(ODEME_TUTARI),0) FROM dbo.ODEMELER WHERE SIGORTA_ID = P.SIGORTA_ID)
            WHEN P.BAKIM_ID IS NOT NULL THEN (SELECT COALESCE(SUM(ODEME_TUTARI),0) FROM dbo.ODEMELER WHERE BAKIM_ID = P.BAKIM_ID)
            WHEN P.KAZA_ID IS NOT NULL THEN (SELECT COALESCE(SUM(ODEME_TUTARI),0) FROM dbo.ODEMELER WHERE KAZA_ID = P.KAZA_ID)
            ELSE NULL
          END AS TOTAL_PAID
        FROM dbo.ODEMELER P
      )
      SELECT P.*,
             R.KIRALAMA_ID,
             P.CEZA_ID, P.SIGORTA_ID, P.BAKIM_ID, P.KAZA_ID,
             A.PLAKA, M.Marka, M.Model,
             I.SIGORTA_ADI, B.BAKIM_TURU, K.HASAR_TURU,
             CASE 
               WHEN PA.TOTAL_TARGET IS NULL THEN 'Diğer'
               WHEN PA.TOTAL_TARGET = 0 THEN 'Yok'
               WHEN COALESCE(PA.TOTAL_PAID,0) >= PA.TOTAL_TARGET THEN 'Ödendi'
               WHEN COALESCE(PA.TOTAL_PAID,0) > 0 THEN 'Kısmi'
               ELSE 'Yok'
             END AS PAY_STATUS
      FROM dbo.ODEMELER P
      LEFT JOIN PayAgg PA ON PA.ODEME_ID = P.ODEME_ID
      LEFT JOIN dbo.KIRALAMA R ON P.KIRALAMA_ID = R.KIRALAMA_ID
      LEFT JOIN dbo.CEZA C ON P.CEZA_ID = C.CEZA_ID
      LEFT JOIN dbo.SIGORTA I ON P.SIGORTA_ID = I.SIGORTA_ID
      LEFT JOIN dbo.BAKIM_KAYITLARI B ON P.BAKIM_ID = B.BAKIM_ID
      LEFT JOIN dbo.KAZA_KAYITLARI K ON P.KAZA_ID = K.KAZA_ID
      LEFT JOIN dbo.ARAC A ON
         (R.SASE_NO = A.SASE_NO) OR
         (I.SASE_NO = A.SASE_NO) OR
         (B.SASE_NO = A.SASE_NO) OR
         (R.SASE_NO = A.SASE_NO AND K.KAZA_ID IS NOT NULL)
      LEFT JOIN dbo.MODEL M ON A.MODEL_ID = M.MODEL_ID
      WHERE
        (R.ALIS_SUBE_ID = $subeId AND P.KIRALAMA_ID IS NOT NULL)
        OR (I.SIGORTA_ID IS NOT NULL AND A.GUNCEL_SUBE_ID = $subeId)
        OR (B.BAKIM_ID IS NOT NULL AND A.GUNCEL_SUBE_ID = $subeId)
        OR (K.KAZA_ID IS NOT NULL AND R.ALIS_SUBE_ID = $subeId)
        OR (P.KIRALAMA_ID IS NULL AND P.CEZA_ID IS NULL AND P.SIGORTA_ID IS NULL AND P.BAKIM_ID IS NULL AND P.KAZA_ID IS NULL)
      $filter
      ORDER BY 
        CASE 
          WHEN (CASE 
                 WHEN PA.TOTAL_TARGET IS NULL THEN 'Diğer'
                 WHEN PA.TOTAL_TARGET = 0 THEN 'Yok'
                 WHEN COALESCE(PA.TOTAL_PAID,0) >= PA.TOTAL_TARGET THEN 'Ödendi'
                 WHEN COALESCE(PA.TOTAL_PAID,0) > 0 THEN 'Kısmi'
                 ELSE 'Yok'
               END) IN ('Yok','Kısmi') THEN 0 ELSE 1 END,
        P.ODEME_ID DESC
    """);
  }

  Future<double> totalByFine(int cezaId) async {
    final rows = await _db.query("SELECT SUM(ODEME_TUTARI) AS T FROM dbo.ODEMELER WHERE CEZA_ID=$cezaId");
    final t = rows.isEmpty ? null : rows.first['T'];
    if (t == null) return 0.0;
    if (t is num) return t.toDouble();
    return double.tryParse(t.toString()) ?? 0.0;
  }

  Future<double> totalByInsurance(int sigortaId) async {
    final rows = await _db.query("SELECT SUM(ODEME_TUTARI) AS T FROM dbo.ODEMELER WHERE SIGORTA_ID=$sigortaId");
    final t = rows.isEmpty ? null : rows.first['T'];
    if (t == null) return 0.0;
    if (t is num) return t.toDouble();
    return double.tryParse(t.toString()) ?? 0.0;
  }

  Future<double> totalByMaintenance(int bakimId) async {
    final rows = await _db.query("SELECT SUM(ODEME_TUTARI) AS T FROM dbo.ODEMELER WHERE BAKIM_ID=$bakimId");
    final t = rows.isEmpty ? null : rows.first['T'];
    if (t == null) return 0.0;
    if (t is num) return t.toDouble();
    return double.tryParse(t.toString()) ?? 0.0;
  }

  Future<double> totalByAccident(int kazaId) async {
    final rows = await _db.query("SELECT SUM(ODEME_TUTARI) AS T FROM dbo.ODEMELER WHERE KAZA_ID=$kazaId");
    final t = rows.isEmpty ? null : rows.first['T'];
    if (t == null) return 0.0;
    if (t is num) return t.toDouble();
    return double.tryParse(t.toString()) ?? 0.0;
  }

  Future<int> _resolveSubeIdForPaymentRow(int odemeId) async {
    final p = await _db.query("SELECT KIRALAMA_ID, CEZA_ID, SIGORTA_ID, BAKIM_ID, KAZA_ID FROM dbo.ODEMELER WHERE ODEME_ID=$odemeId");
    if (p.isEmpty) return (await _db.query("SELECT TOP 1 SUBE_ID FROM dbo.SUBELER ORDER BY SUBE_ID")).first['SUBE_ID'] as int;
    final r = p.first;
    final kiralamaId = r['KIRALAMA_ID'] as int?;
    final cezaId = r['CEZA_ID'] as int?;
    final sigortaId = r['SIGORTA_ID'] as int?;
    final bakimId = r['BAKIM_ID'] as int?;
    final kazaId = r['KAZA_ID'] as int?;

    if (kiralamaId != null) {
      final rows = await _db.query("SELECT ALIS_SUBE_ID FROM dbo.KIRALAMA WHERE KIRALAMA_ID=$kiralamaId");
      if (rows.isNotEmpty) return rows.first['ALIS_SUBE_ID'] as int;
    }
    if (cezaId != null) {
      final rows = await _db.query("SELECT R.ALIS_SUBE_ID AS SUBE FROM dbo.CEZA C JOIN dbo.KIRALAMA R ON C.KIRALAMA_ID=R.KIRALAMA_ID WHERE C.CEZA_ID=$cezaId");
      if (rows.isNotEmpty) return rows.first['SUBE'] as int;
    }
    if (sigortaId != null) {
      final rows = await _db.query("SELECT A.GUNCEL_SUBE_ID AS SUBE FROM dbo.SIGORTA I JOIN dbo.ARAC A ON I.SASE_NO=A.SASE_NO WHERE I.SIGORTA_ID=$sigortaId");
      if (rows.isNotEmpty) return rows.first['SUBE'] as int;
    }
    if (bakimId != null) {
      final rows = await _db.query("SELECT A.GUNCEL_SUBE_ID AS SUBE FROM dbo.BAKIM_KAYITLARI B JOIN dbo.ARAC A ON B.SASE_NO=A.SASE_NO WHERE B.BAKIM_ID=$bakimId");
      if (rows.isNotEmpty) return rows.first['SUBE'] as int;
    }
    if (kazaId != null) {
      final rows = await _db.query("SELECT R.ALIS_SUBE_ID AS SUBE FROM dbo.KAZA_KAYITLARI K JOIN dbo.KIRALAMA R ON K.KIRALAMA_ID=R.KIRALAMA_ID WHERE K.KAZA_ID=$kazaId");
      if (rows.isNotEmpty) return rows.first['SUBE'] as int;
    }
    return (await _db.query("SELECT TOP 1 SUBE_ID FROM dbo.SUBELER ORDER BY SUBE_ID")).first['SUBE_ID'] as int;
  }

  Future<void> add({
    int? kiralamaId,
    int? cezaId,
    int? sigortaId,
    int? bakimId,
    int? kazaId,
    required double tutar,
    required String tur,
    required String tipi,
  }) async {
    final tip = tipi.replaceAll("'", "''");
    final t = tur.replaceAll("'", "''");

    int? subeId;
    if (tur == 'Ceza') {
      if (cezaId == null) throw Exception('Ceza seçiniz');
      final cezaRows = await _db.query("SELECT CEZA_TUTAR, C.KIRALAMA_ID, R.ALIS_SUBE_ID AS SUBE FROM dbo.CEZA C JOIN dbo.KIRALAMA R ON C.KIRALAMA_ID=R.KIRALAMA_ID WHERE CEZA_ID=$cezaId");
      if (cezaRows.isEmpty) throw Exception('Ceza bulunamadı');
      final cezaTutar = (cezaRows.first['CEZA_TUTAR'] as num).toDouble();
      final already = await totalByFine(cezaId);
      if (already >= cezaTutar) { throw Exception('Bu ceza zaten tamamen ödenmiş (toplam ${already.toStringAsFixed(2)} TL)'); }
      if (already + tutar > cezaTutar + 0.0001) {
        final kalan = cezaTutar - already;
        throw Exception('Fazla ödeme! Kalan tutar: ${kalan.toStringAsFixed(2)} TL');
      }
      subeId = cezaRows.first['SUBE'] as int;
      kiralamaId = cezaRows.first['KIRALAMA_ID'] as int;
      sigortaId = null; bakimId = null; kazaId = null;
    } else if (tur == 'Kira' || tur == 'Depozito' || tur == 'İade') {
      if (kiralamaId == null) throw Exception('Kiralama seçiniz');
      final rows = await _db.query("SELECT ALIS_SUBE_ID FROM dbo.KIRALAMA WHERE KIRALAMA_ID=$kiralamaId");
      if (rows.isEmpty) throw Exception('Kiralama bulunamadı');
      subeId = rows.first['ALIS_SUBE_ID'] as int;
      cezaId = null; sigortaId = null; bakimId = null; kazaId = null;
    } else if (tur == 'Sigorta') {
      if (sigortaId == null) throw Exception('Sigorta seçiniz');
      final rows = await _db.query("SELECT MALIYET, A.GUNCEL_SUBE_ID AS SUBE FROM dbo.SIGORTA I JOIN dbo.ARAC A ON I.SASE_NO=A.SASE_NO WHERE I.SIGORTA_ID=$sigortaId");
      if (rows.isEmpty) throw Exception('Sigorta/araç bulunamadı');
      final maliyet = (rows.first['MALIYET'] as num?)?.toDouble() ?? 0.0;
      if (maliyet <= 0) throw Exception('Sigorta maliyeti 0 — ödeme yapılamaz');
      final already = await totalByInsurance(sigortaId);
      if (already >= maliyet) {
        throw Exception('Bu sigorta zaten tamamen ödenmiş (toplam ${already.toStringAsFixed(2)} TL)');
      }
      if (already + tutar > maliyet + 0.0001) {
        final kalan = maliyet - already;
        throw Exception('Fazla ödeme! Kalan tutar: ${kalan.toStringAsFixed(2)} TL');
      }
      subeId = rows.first['SUBE'] as int;
      kiralamaId = null; cezaId = null; bakimId = null; kazaId = null;
    } else if (tur == 'Bakım') {
      if (bakimId == null) throw Exception('Bakım seçiniz');
      final rows = await _db.query("SELECT BAKIM_UCRETI, A.GUNCEL_SUBE_ID AS SUBE FROM dbo.BAKIM_KAYITLARI B JOIN dbo.ARAC A ON B.SASE_NO=A.SASE_NO WHERE B.BAKIM_ID=$bakimId");
      if (rows.isEmpty) throw Exception('Bakım/araç bulunamadı');
      final ucret = (rows.first['BAKIM_UCRETI'] as num?)?.toDouble() ?? 0.0;
      if (ucret <= 0) throw Exception('Bakım ücreti 0 — ödeme yapılamaz');
      final already = await totalByMaintenance(bakimId);
      if (already >= ucret) {
        throw Exception('Bu bakım zaten tamamen ödenmiş (toplam ${already.toStringAsFixed(2)} TL)');
      }
      if (already + tutar > ucret + 0.0001) {
        final kalan = ucret - already;
        throw Exception('Fazla ödeme! Kalan tutar: ${kalan.toStringAsFixed(2)} TL');
      }
      subeId = rows.first['SUBE'] as int;
      kiralamaId = null; cezaId = null; sigortaId = null; kazaId = null;
    } else if (tur == 'Kaza') {
      if (kazaId == null) throw Exception('Kaza seçiniz');
      final rows = await _db.query("SELECT K.HASAR_MIKTARI, R.ALIS_SUBE_ID AS SUBE, K.KIRALAMA_ID FROM dbo.KAZA_KAYITLARI K JOIN dbo.KIRALAMA R ON K.KIRALAMA_ID=R.KIRALAMA_ID WHERE KAZA_ID=$kazaId");
      if (rows.isEmpty) throw Exception('Kaza/kiralama bulunamadı');
      final hasar = (rows.first['HASAR_MIKTARI'] as num?)?.toDouble() ?? 0.0;
      if (hasar <= 0) throw Exception('Hasar 0 — ödeme yapılamaz');
      final already = await totalByAccident(kazaId);
      if (already >= hasar) {
        throw Exception('Bu kaza zaten tamamen ödenmiş (toplam ${already.toStringAsFixed(2)} TL)');
      }
      if (already + tutar > hasar + 0.0001) {
        final kalan = hasar - already;
        throw Exception('Fazla ödeme! Kalan tutar: ${kalan.toStringAsFixed(2)} TL');
      }
      subeId = rows.first['SUBE'] as int;
      kiralamaId = rows.first['KIRALAMA_ID'] as int;
      cezaId = null; sigortaId = null; bakimId = null;
    } else { subeId = null; kiralamaId = null; cezaId = null; sigortaId = null; bakimId = null; kazaId = null; }

    final kiraV = kiralamaId == null ? 'NULL' : '$kiralamaId';
    final cezaV = cezaId == null ? 'NULL' : '$cezaId';
    final sigV = sigortaId == null ? 'NULL' : '$sigortaId';
    final bakV = bakimId == null ? 'NULL' : '$bakimId';
    final kazV = kazaId == null ? 'NULL' : '$kazaId';

    await _db.execute("""
      INSERT INTO dbo.ODEMELER (KIRALAMA_ID, CEZA_ID, SIGORTA_ID, BAKIM_ID, KAZA_ID, ODEME_TUTARI, ODEME_TURU, ODEME_TIPI)
      VALUES ($kiraV, $cezaV, $sigV, $bakV, $kazV, ${tutar.toStringAsFixed(2)}, '$t', '$tip')
    """);
    final odemeId = (await _db.query("SELECT MAX(ODEME_ID) AS ID FROM dbo.ODEMELER")).first['ID'] as int;

    final resolvedSubeId = subeId ?? (await _resolveSubeIdForPaymentRow(odemeId));
    await _logs.add(
      subeId: resolvedSubeId,
      calisanId: null,
      action: 'Ödeme',
      message: 'Ödeme eklendi: $t • ${tutar.toStringAsFixed(2)} TL',
      details: { 'odemeId': odemeId, 'kiralamaId': kiralamaId, 'cezaId': cezaId, 'sigortaId': sigortaId, 'bakimId': bakimId, 'kazaId': kazaId, 'tutar': tutar, 'tur': tur, 'tipi': tipi },
      relatedType: 'ODEME',
      relatedId: odemeId,
    );
  }

  Future<void> update({required int odemeId, double? tutar, String? tur, String? tipi}) async {
    if (tutar != null) {
      final row = await _db.query("SELECT CEZA_ID, SIGORTA_ID, BAKIM_ID, KAZA_ID FROM dbo.ODEMELER WHERE ODEME_ID=$odemeId");
      if (row.isEmpty) throw Exception('Ödeme bulunamadı');
      final cezaId = row.first['CEZA_ID'] as int?;
      final sigortaId = row.first['SIGORTA_ID'] as int?;
      final bakimId = row.first['BAKIM_ID'] as int?;
      final kazaId = row.first['KAZA_ID'] as int?;

      if (cezaId != null) {
        final cezaRows = await _db.query("SELECT CEZA_TUTAR FROM dbo.CEZA WHERE CEZA_ID=$cezaId");
        if (cezaRows.isEmpty) throw Exception('Ceza bulunamadı');
        final cezaTutar = (cezaRows.first['CEZA_TUTAR'] as num).toDouble();
        final paidExceptThis = await _db.query("SELECT SUM(ODEME_TUTARI) AS TOPLAM FROM dbo.ODEMELER WHERE CEZA_ID=$cezaId AND ODEME_ID<>$odemeId");
        final already = (paidExceptThis.first['TOPLAM'] as num?)?.toDouble() ?? 0.0;
        if (already + tutar > cezaTutar + 0.0001) {
          final kalan = cezaTutar - already;
          throw Exception('Fazla ödeme! Bu ödemeyi en fazla ${kalan.toStringAsFixed(2)} TL yapabilirsiniz.');
        }
      }
      if (sigortaId != null) {
        final rows = await _db.query("SELECT MALIYET FROM dbo.SIGORTA WHERE SIGORTA_ID=$sigortaId");
        final maliyet = (rows.first['MALIYET'] as num?)?.toDouble() ?? 0.0;
        final paidExceptThis = await _db.query("SELECT SUM(ODEME_TUTARI) AS TOPLAM FROM dbo.ODEMELER WHERE SIGORTA_ID=$sigortaId AND ODEME_ID<>$odemeId");
        final already = (paidExceptThis.first['TOPLAM'] as num?)?.toDouble() ?? 0.0;
        if (maliyet > 0 && already + tutar > maliyet + 0.0001) {
          final kalan = maliyet - already;
          throw Exception('Fazla ödeme! Bu ödemeyi en fazla ${kalan.toStringAsFixed(2)} TL yapabilirsiniz.');
        }
      }
      if (bakimId != null) {
        final rows = await _db.query("SELECT BAKIM_UCRETI FROM dbo.BAKIM_KAYITLARI WHERE BAKIM_ID=$bakimId");
        final ucret = (rows.first['BAKIM_UCRETI'] as num?)?.toDouble() ?? 0.0;
        final paidExceptThis = await _db.query("SELECT SUM(ODEME_TUTARI) AS TOPLAM FROM dbo.ODEMELER WHERE BAKIM_ID=$bakimId AND ODEME_ID<>$odemeId");
        final already = (paidExceptThis.first['TOPLAM'] as num?)?.toDouble() ?? 0.0;
        if (ucret > 0 && already + tutar > ucret + 0.0001) {
          final kalan = ucret - already;
          throw Exception('Fazla ödeme! Bu ödemeyi en fazla ${kalan.toStringAsFixed(2)} TL yapabilirsiniz.');
        }
      }
      if (kazaId != null) {
        final rows = await _db.query("SELECT HASAR_MIKTARI FROM dbo.KAZA_KAYITLARI WHERE KAZA_ID=$kazaId");
        final hasar = (rows.first['HASAR_MIKTARI'] as num?)?.toDouble() ?? 0.0;
        final paidExceptThis = await _db.query("SELECT SUM(ODEME_TUTARI) AS TOPLAM FROM dbo.ODEMELER WHERE KAZA_ID=$kazaId AND ODEME_ID<>$odemeId");
        final already = (paidExceptThis.first['TOPLAM'] as num?)?.toDouble() ?? 0.0;
        if (hasar > 0 && already + tutar > hasar + 0.0001) {
          final kalan = hasar - already;
          throw Exception('Fazla ödeme! Bu ödemeyi en fazla ${kalan.toStringAsFixed(2)} TL yapabilirsiniz.');
        }
      }
    }
    final ups = <String>[];
    if (tutar != null) ups.add("ODEME_TUTARI=${tutar.toStringAsFixed(2)}");
    if (tur != null) ups.add("ODEME_TURU='${tur.replaceAll("'", "''")}'");
    if (tipi != null) ups.add("ODEME_TIPI='${tipi.replaceAll("'", "''")}'");
    if (ups.isEmpty) return;
    await _db.execute("UPDATE dbo.ODEMELER SET ${ups.join(', ')} WHERE ODEME_ID=$odemeId");

    final subeId = await _resolveSubeIdForPaymentRow(odemeId);
    await _logs.add(
      subeId: subeId,
      calisanId: null,
      action: 'Ödeme',
      message: 'Ödeme güncellendi',
      details: { 'odemeId': odemeId, 'tutar': tutar, 'tur': tur, 'tipi': tipi },
      relatedType: 'ODEME',
      relatedId: odemeId,
    );
  }

  Future<void> delete(int odemeId) async {
    final subeId = await _resolveSubeIdForPaymentRow(odemeId);
    await _db.execute("DELETE FROM dbo.ODEMELER WHERE ODEME_ID=$odemeId");
    await _logs.add(
      subeId: subeId,
      calisanId: null,
      action: 'Ödeme',
      message: 'Ödeme silindi',
      details: { 'odemeId': odemeId },
      relatedType: 'ODEME',
      relatedId: odemeId,
    );
  }

  Future<List<Map<String, dynamic>>> listByRental(int kiralamaId) async {
    return _db.query("SELECT * FROM dbo.ODEMELER WHERE KIRALAMA_ID=$kiralamaId ORDER BY ODEME_ID DESC");
  }
}