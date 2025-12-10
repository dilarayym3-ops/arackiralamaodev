import 'dart:convert';
import 'package:mssql_connection/mssql_connection.dart';

class MssqlService {
  static final MssqlService _instance = MssqlService._internal();
  factory MssqlService() => _instance;
  MssqlService._internal();

  final _conn = MssqlConnection.getInstance();
  bool _connected = false;

  String server = ".";
  String port = "1433";
  String database = "ARACKIRALAMADB";
  String username = "flutter_user";
  String password = "58450120";

  Future<void> connectIfNeeded() async {
    if (_connected) return;
    await _conn.connect(
      ip: server,
      port: port,
      databaseName: database,
      username: username,
      password: password,
    );
    _connected = true;
  }

  Future<List<Map<String, dynamic>>> query(String sql) async {
    await connectIfNeeded();
    try {
      final result = await _conn.getData(sql);
      final parsed = jsonDecode(result);
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(parsed);
      }
      return const [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> execute(String sql) async {
    await connectIfNeeded();
    try {
      await _conn.writeData(sql);
    } catch (e) {
      rethrow;
    }
  }
}