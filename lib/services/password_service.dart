// İki seviyeli şifre (Uygulama Şifresi - Seviye 1, Yönetici Şifresi - Seviye 2) yönetimi.
// Basit local storage (SharedPreferences) ile tutulur. Desktop’da da çalışır.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordService {
  static const _kPass1 = 'app_password_level1';
  static const _kPass2 = 'app_password_level2';

  // Seviye 1: Uygulama girişi
  static Future<bool> isPassword1Default() async {
    final sp = await SharedPreferences.getInstance();
    final p = sp.getString(_kPass1);
    return (p == null || p.isEmpty);
  }

  static Future<void> setPassword1(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPass1, value);
  }

  static Future<bool> verifyPassword1(String value) async {
    final sp = await SharedPreferences.getInstance();
    final p = sp.getString(_kPass1);
    return (p != null && p == value);
  }

  // Seviye 2: Yönetici şifresi (Çalışanlar/Şubeler gibi sayfalarda)
  static Future<bool> isPassword2Default() async {
    final sp = await SharedPreferences.getInstance();
    final p = sp.getString(_kPass2);
    return (p == null || p.isEmpty);
  }

  static Future<void> setPassword2(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPass2, value);
  }

  static Future<bool> verifyPassword2(String value) async {
    final sp = await SharedPreferences.getInstance();
    final p = sp.getString(_kPass2);
    return (p != null && p == value);
  }

  // Seviye 2 şifre isteyen sayfalarda diyalog
  static Future<bool> showPasswordDialog(
    BuildContext context, {
    required int passwordLevel, // 1 veya 2
    String title = 'Şifre Girişi',
  }) async {
    final ctrl = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) {
                    // no-op
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
              FilledButton(
                onPressed: () async {
                  final v = ctrl.text.trim();
                  final ok = passwordLevel == 2 ? await verifyPassword2(v) : await verifyPassword1(v);
                  if (ok) {
                    Navigator.pop(ctx, true);
                  } else {
                    setState(() => error = 'Şifre yanlış');
                  }
                },
                child: const Text('Giriş'),
              ),
            ],
          );
        });
      },
    );
    return ok ?? false;
  }
}