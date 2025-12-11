import 'package:flutter/material.dart';
import '../../../services/password_service.dart';

class PasswordManagementPage extends StatefulWidget {
  const PasswordManagementPage({super.key});
  @override
  State<PasswordManagementPage> createState() => _PasswordManagementPageState();
}

class _PasswordManagementPageState extends State<PasswordManagementPage> {
  final _currentPass1 = TextEditingController();
  final _newPass1 = TextEditingController();
  final _confirmPass1 = TextEditingController();

  final _currentPass2 = TextEditingController();
  final _newPass2 = TextEditingController();
  final _confirmPass2 = TextEditingController();

  String? _error1;
  String? _success1;
  String? _error2;
  String? _success2;

  bool _showPass1 = false;
  bool _showPass2 = false;

  Future<void> _changePassword1() async {
    setState(() {
      _error1 = null;
      _success1 = null;
    });

    if (_currentPass1.text.trim().isEmpty) {
      setState(() => _error1 = 'Mevcut şifreyi giriniz');
      return;
    }

    final isValid = await PasswordService.verifyPassword1(_currentPass1.text.trim());
    if (!isValid) {
      setState(() => _error1 = 'Mevcut şifre yanlış');
      return;
    }

    if (_newPass1.text.trim().length < 4) {
      setState(() => _error1 = 'Yeni şifre en az 4 karakter olmalı');
      return;
    }

    if (_newPass1.text.trim() != _confirmPass1.text.trim()) {
      setState(() => _error1 = 'Şifreler eşleşmiyor');
      return;
    }

    await PasswordService.setPassword1(_newPass1.text.trim());
    setState(() {
      _success1 = 'Uygulama şifresi başarıyla değiştirildi';
      _currentPass1.clear();
      _newPass1.clear();
      _confirmPass1.clear();
    });
  }

  Future<void> _changePassword2() async {
    setState(() {
      _error2 = null;
      _success2 = null;
    });

    if (_currentPass2.text.trim().isEmpty) {
      setState(() => _error2 = 'Mevcut şifreyi giriniz');
      return;
    }

    final isValid = await PasswordService.verifyPassword2(_currentPass2.text.trim());
    if (!isValid) {
      setState(() => _error2 = 'Mevcut şifre yanlış');
      return;
    }

    if (_newPass2.text.trim().length < 4) {
      setState(() => _error2 = 'Yeni şifre en az 4 karakter olmalı');
      return;
    }

    if (_newPass2.text.trim() != _confirmPass2.text.trim()) {
      setState(() => _error2 = 'Şifreler eşleşmiyor');
      return;
    }

    await PasswordService.setPassword2(_newPass2.text.trim());
    setState(() {
      _success2 = 'Yönetici şifresi başarıyla değiştirildi';
      _currentPass2.clear();
      _newPass2.clear();
      _confirmPass2.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security, size: 32, color: Colors.indigo),
              SizedBox(width: 12),
              Text('Şifre Yönetimi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu sayfadan uygulama şifrelerini yönetebilirsiniz. İki farklı şifre seviyesi bulunmaktadır.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Şifre 1 - Uygulama Girişi
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seviye 1: Uygulama Girişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currentPass1,
                    obscureText: !_showPass1,
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifre',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPass1 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass1 = !_showPass1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPass1,
                    obscureText: !_showPass1,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPass1,
                    obscureText: !_showPass1,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  if (_error1 != null) Text(_error1!, style: const TextStyle(color: Colors.red)),
                  if (_success1 != null) Text(_success1!, style: const TextStyle(color: Colors.green)),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _changePassword1, icon: const Icon(Icons.save), label: const Text('Şifreyi Değiştir')),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Şifre 2 - Yönetici (Çalışanlar/Şubeler gibi sayfalar)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seviye 2: Yönetici Şifresi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currentPass2,
                    obscureText: !_showPass2,
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifre',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPass2 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass2 = !_showPass2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPass2,
                    obscureText: !_showPass2,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPass2,
                    obscureText: !_showPass2,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  if (_error2 != null) Text(_error2!, style: const TextStyle(color: Colors.red)),
                  if (_success2 != null) Text(_success2!, style: const TextStyle(color: Colors.green)),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _changePassword2, icon: const Icon(Icons.save), label: const Text('Şifreyi Değiştir')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}