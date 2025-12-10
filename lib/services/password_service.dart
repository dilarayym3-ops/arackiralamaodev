import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama içi şifre yönetim servisi
/// Şifre 1 (Temel): Uygulama girişi ve Loglar sayfası
/// Şifre 2 (Yönetici): Çalışanlar ve Şubeler sayfaları
class PasswordService {
  static const String _keyPassword1 = 'app_password_level1';
  static const String _keyPassword2 = 'app_password_level2';
  static const String _defaultPassword1 = '0000';
  static const String _defaultPassword2 = '1234';

  /// Şifre 1'i (Temel) yükle
  Future<String> getPassword1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword1) ?? _defaultPassword1;
  }

  /// Şifre 2'yi (Yönetici) yükle
  Future<String> getPassword2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword2) ?? _defaultPassword2;
  }

  /// Şifre 1'i (Temel) kaydet
  Future<void> setPassword1(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword1, password);
  }

  /// Şifre 2'yi (Yönetici) kaydet
  Future<void> setPassword2(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword2, password);
  }

  /// Şifre 1'i doğrula
  Future<bool> verifyPassword1(String input) async {
    final stored = await getPassword1();
    return input == stored;
  }

  /// Şifre 2'yi doğrula
  Future<bool> verifyPassword2(String input) async {
    final stored = await getPassword2();
    return input == stored;
  }

  /// Şifre 1 varsayılan mı kontrol et
  Future<bool> isPassword1Default() async {
    final stored = await getPassword1();
    return stored == _defaultPassword1;
  }

  /// Şifre 2 varsayılan mı kontrol et
  Future<bool> isPassword2Default() async {
    final stored = await getPassword2();
    return stored == _defaultPassword2;
  }

  /// Şifre doğrulama dialogu göster
  static Future<bool> showPasswordDialog({
    required BuildContext context,
    required int level,
    String? title,
  }) async {
    final service = PasswordService();
    final controller = TextEditingController();
    bool obscureText = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title ?? (level == 1 ? 'Şifre 1 Gerekli' : 'Şifre 2 Gerekli (Yönetici)')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    level == 1
                        ? 'Bu işlem için Şifre 1 (Temel) gereklidir.'
                        : 'Bu işlem için Şifre 2 (Yönetici) gereklidir.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (_) async {
                      final isValid = level == 1
                          ? await service.verifyPassword1(controller.text)
                          : await service.verifyPassword2(controller.text);
                      Navigator.of(context).pop(isValid);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final isValid = level == 1
                        ? await service.verifyPassword1(controller.text)
                        : await service.verifyPassword2(controller.text);
                    Navigator.of(context).pop(isValid);
                  },
                  child: const Text('Doğrula'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      return true;
    } else if (result == false) {
      // Yanlış şifre
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre yanlış!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return false; // İptal
  }
}
