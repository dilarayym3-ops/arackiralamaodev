import 'package:flutter/material.dart';
import '../../models/session.dart';
import 'pages/home_dashboard_page.dart';
import 'pages/login_page.dart';

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = Session().isLoggedIn;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: loggedIn ? const HomeDashboardPage() : const LoginPage(),
    );
  }
}