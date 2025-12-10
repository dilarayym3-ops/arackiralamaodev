import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'pages/login_page.dart';
import 'pages/home_dashboard_page.dart';
import '../../models/session.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});
  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  Future<void> _initWindow() async {
    if (! Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
      await windowManager. setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arac Kiralama Yonetim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Session().isLoggedIn ? const HomeDashboardPage() : const LoginPage(),
    );
  }
}