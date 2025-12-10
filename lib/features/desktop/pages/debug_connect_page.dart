import 'package:flutter/material.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'dart:convert';

class DebugConnectPage extends StatefulWidget {
  const DebugConnectPage({super.key});
  @override
  State<DebugConnectPage> createState() => _DebugConnectPageState();
}

class _DebugConnectPageState extends State<DebugConnectPage> {
  final _mssql = MssqlConnection.getInstance();
  bool _ok = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _test();
  }

  Future<void> _test() async {
    try {
      await _mssql.connect(
        ip: ".",
        port: "1433",
        databaseName: "ARACKIRALAMADB",
        username: "flutter_user",
        password: "58450120",
      );
      final dbRow = await _mssql.getData("SELECT DB_NAME() AS DBName");
      final objects = await _mssql.getData("""
        SELECT name, type_desc
        FROM sys.objects
        WHERE name IN ('v_AracDetay','ARAC','MODEL','SUBELER')
      """);
      setState(() {
        _ok = true;
        _msg = 'DB: ${jsonDecode(dbRow)} • Objects: ${jsonDecode(objects)}';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _msg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bağlantı Test')),
      body: Center(child: Text(_ok ? 'OK: $_msg' : 'Hata: $_msg')),
    );
  }
}