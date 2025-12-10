import '../db/mssql_service.dart';

class LogsRepository {
  final _db = MssqlService();

  Future<void> add({
    required int subeId,
    int? calisanId,
    required String action,
    required String message,
    Map<String, dynamic>? details,
    String? relatedType,
    int? relatedId,
  }) async {
    final act = action.replaceAll("'", "''");
    final msg = message.replaceAll("'", "''");
    final det = details == null ? 'NULL' : "N'${_escape(details)}'";
    final rt = relatedType == null ? 'NULL' : "'${relatedType.replaceAll("'", "''")}'";
    final rid = relatedId == null ? 'NULL' : '$relatedId';
    await _db.execute("""
      INSERT INTO dbo.LOGS (SUBE_ID, CALISAN_ID, ACTION, MESSAGE, DETAILS, RELATED_TYPE, RELATED_ID)
      VALUES ($subeId, ${calisanId ?? 'NULL'}, '$act', '$msg', $det, $rt, $rid)
    """);
  }

  String _escape(Map<String, dynamic> m) {
    final s = m.toString(); // basit JSON-benzeri
    return s.replaceAll("'", "''");
  }

  // Genel listeleme (filtreli, sayfalı)
  Future<List<Map<String, dynamic>>> list({
    int? subeId,
    String? action,
    String? relatedType,
    String? q,
    int page = 1,
    int pageSize = 200,
  }) async {
    final filters = <String>[];
    if (subeId != null) filters.add('SUBE_ID = $subeId');
    if (action != null && action.trim().isNotEmpty) filters.add("ACTION LIKE '%${action.replaceAll("'", "''")}%'");
    if (relatedType != null && relatedType.trim().isNotEmpty) filters.add("RELATED_TYPE = '${relatedType.replaceAll("'", "''")}'");
    if (q != null && q.trim().isNotEmpty) {
      final s = q.replaceAll("'", "''");
      filters.add("(MESSAGE LIKE '%$s%' OR DETAILS LIKE N'%$s%')");
    }
    final where = filters.isEmpty ? '' : 'WHERE ' + filters.join(' AND ');
    final offset = (page - 1) * pageSize;
    return _db.query("""
      SELECT * FROM dbo.LOGS
      $where
      ORDER BY CREATED_AT DESC, LOG_ID DESC
      OFFSET $offset ROWS FETCH NEXT $pageSize ROWS ONLY
    """);
  }

  // Şubeye göre listeleme (LogsPage’in beklediği basit API)
  Future<List<Map<String, dynamic>>> listByBranch(int subeId, {String? q}) async {
    return list(subeId: subeId, q: q, page: 1, pageSize: 200);
  }
}