import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import '../../../data/repositories/sube_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../models/session.dart';
import '../../../widgets/search_select_dialog.dart';
import '../../../services/password_service.dart';
import 'home_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _subeRepo = SubeRepository();
  final _empRepo = EmployeeRepository();
  final _authRepo = AuthRepository();

  final _passCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  Map<String, dynamic>? _selSube;
  Map<String, dynamic>? _selEmp;
  bool _loading = false;
  String? _error;
  bool _showPassword = false;

  bool _needsSetup = false;
  bool _passVerified = false;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final isDefault = await PasswordService.isPassword1Default();
    setState(() {
      _needsSetup = isDefault;
    });
  }

  Future<void> _verifyPassword() async {
    if (_passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Şifre giriniz');
      return;
    }
    final isValid = await PasswordService.verifyPassword1(_passCtrl.text.trim());
    if (isValid) {
      setState(() {
        _passVerified = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'Şifre yanlış');
    }
  }

  Future<void> _setupPassword() async {
    if (_newPassCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Yeni şifre giriniz');
      return;
    }
    if (_newPassCtrl.text.trim().length < 4) {
      setState(() => _error = 'Şifre en az 4 karakter olmalı');
      return;
    }
    if (_newPassCtrl.text.trim() != _confirmPassCtrl.text.trim()) {
      setState(() => _error = 'Şifreler eşleşmiyor');
      return;
    }
    await PasswordService.setPassword1(_newPassCtrl.text.trim());
    setState(() {
      _needsSetup = false;
      _passVerified = true;
      _error = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre başarıyla oluşturuldu')),
      );
    }
  }

  Future<Map<String, dynamic>?> _pickSube() {
    return SearchSelectDialog.show(
      context,
      title: 'Şube Seç',
      loader: (q) async {
        final rows = await _subeRepo.getAll();
        final term = q.toLowerCase();
        return rows.where((s) =>
          (s['SUBE_ADI'] ?? '').toString().toLowerCase().contains(term) ||
          (s['IL'] ?? '').toString().toLowerCase().contains(term) ||
          (s['ILCE'] ?? '').toString().toLowerCase().contains(term)
        ).toList();
      },
      itemTitle: (s) => '${s['SUBE_ADI'] ?? ''}',
      itemSubtitle: (s) => '${s['IL'] ?? ''}/${s['ILCE'] ?? ''}',
    );
  }

  Future<Map<String, dynamic>?> _pickEmployee() {
    final subeId = _selSube?['SUBE_ID'] as int?;
    if (subeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce şube seçin')));
      return Future.value(null);
    }
    return SearchSelectDialog.show(
      context,
      title: 'Çalışan Seç',
      loader: (q) async => await _empRepo.listBySube(subeId, q: q),
      itemTitle: (e) => '${e['AD'] ?? ''} ${e['SOYAD'] ?? ''}',
      itemSubtitle: (e) => '${e['E-MAIL'] ?? ''} - ${e['POZISYON'] ?? ''}',
    );
  }

  Future<void> _login() async {
    final subeId = _selSube?['SUBE_ID'] as int?;
    final empId = _selEmp?['CALISAN_ID'] as int?;
    if (subeId == null || empId == null) {
      setState(() => _error = 'Şube ve çalışan seçmelisiniz');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _authRepo.loginWithCalisanId(subeId: subeId, calisanId: empId);
      if (user == null) {
        setState(() => _error = 'Giriş başarısız');
      } else {
        Session().current = user;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeDashboardPage()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exitApp() async {
    try {
      await windowManager.close();
    } catch (_) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Kiralama Sistemi'),
        actions: [
          IconButton(tooltip: 'Çıkış', onPressed: _exitApp, icon: const Icon(Icons.close)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_needsSetup) {
      return _buildSetupForm();
    }
    if (!_passVerified) {
      return _buildPasswordForm();
    }
    return _buildLoginForm();
  }

  Widget _buildSetupForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_open, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Text('İlk Kurulum', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Uygulama şifresi henüz belirlenmemiş. Lütfen yeni bir şifre oluşturun.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: _newPassCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Yeni Şifre',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPassCtrl,
          obscureText: !_showPassword,
          decoration: const InputDecoration(
            labelText: 'Şifre Tekrar',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _setupPassword,
            icon: const Icon(Icons.check),
            label: const Text('Şifre Oluştur'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 64, color: Colors.indigo),
        const SizedBox(height: 16),
        Text('Uygulama Girişi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Şifre',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          onSubmitted: (_) => _verifyPassword(),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _verifyPassword,
            child: const Text('Giriş'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.business, size: 64, color: Colors.indigo),
        const SizedBox(height: 16),
        Text('Şube ve Çalışan Seçimi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final s = await _pickSube();
              if (s != null) setState(() => _selSube = s);
            },
            icon: const Icon(Icons.home_work),
            label: Text(_selSube == null ? 'Şube Seç' : '${_selSube!['SUBE_ADI']}'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final e = await _pickEmployee();
              if (e != null) setState(() => _selEmp = e);
            },
            icon: const Icon(Icons.badge),
            label: Text(_selEmp == null ? 'Çalışan Seç' : '${_selEmp!['AD']} ${_selEmp!['SOYAD']}'),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Giriş Yap'),
          ),
        ),
      ],
    );
  }
}