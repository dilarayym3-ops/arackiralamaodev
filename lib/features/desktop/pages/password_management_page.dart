import 'package:flutter/material.dart';
import '../../../services/password_service.dart';
import '../../../data/repositories/logs_repository.dart';
import '../../../models/session.dart';

class PasswordManagementPage extends StatefulWidget {
  const PasswordManagementPage({super.key});

  @override
  State<PasswordManagementPage> createState() => _PasswordManagementPageState();
}

class _PasswordManagementPageState extends State<PasswordManagementPage> {
  final _passwordService = PasswordService();
  final _logsRepo = LogsRepository();

  final _oldPass1Ctrl = TextEditingController();
  final _newPass1Ctrl = TextEditingController();
  final _confirmPass1Ctrl = TextEditingController();

  final _oldPass2Ctrl = TextEditingController();
  final _newPass2Ctrl = TextEditingController();
  final _confirmPass2Ctrl = TextEditingController();

  bool _showPass1Old = false;
  bool _showPass1New = false;
  bool _showPass1Confirm = false;

  bool _showPass2Old = false;
  bool _showPass2New = false;
  bool _showPass2Confirm = false;

  String? _error1;
  String? _error2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key, color: Colors.indigo, size: 32),
                const SizedBox(width: 12),
                Text('Şifre Yönetimi', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Uygulama şifrelerini buradan değiştirebilirsiniz. İki farklı şifre seviyesi vardır.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Şifre 1 (Temel)
            _buildPasswordCard(
              title: 'Şifre 1 (Temel)',
              description: 'Uygulama girişi ve Loglar sayfası için kullanılır.',
              oldController: _oldPass1Ctrl,
              newController: _newPass1Ctrl,
              confirmController: _confirmPass1Ctrl,
              showOld: _showPass1Old,
              showNew: _showPass1New,
              showConfirm: _showPass1Confirm,
              error: _error1,
              onToggleOld: () => setState(() => _showPass1Old = !_showPass1Old),
              onToggleNew: () => setState(() => _showPass1New = !_showPass1New),
              onToggleConfirm: () => setState(() => _showPass1Confirm = !_showPass1Confirm),
              onSave: _changePassword1,
              icon: Icons.lock,
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            // Şifre 2 (Yönetici)
            _buildPasswordCard(
              title: 'Şifre 2 (Yönetici)',
              description: 'Çalışanlar ve Şubeler sayfaları için kullanılır.',
              oldController: _oldPass2Ctrl,
              newController: _newPass2Ctrl,
              confirmController: _confirmPass2Ctrl,
              showOld: _showPass2Old,
              showNew: _showPass2New,
              showConfirm: _showPass2Confirm,
              error: _error2,
              onToggleOld: () => setState(() => _showPass2Old = !_showPass2Old),
              onToggleNew: () => setState(() => _showPass2New = !_showPass2New),
              onToggleConfirm: () => setState(() => _showPass2Confirm = !_showPass2Confirm),
              onSave: _changePassword2,
              icon: Icons.admin_panel_settings,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard({
    required String title,
    required String description,
    required TextEditingController oldController,
    required TextEditingController newController,
    required TextEditingController confirmController,
    required bool showOld,
    required bool showNew,
    required bool showConfirm,
    required String? error,
    required VoidCallback onToggleOld,
    required VoidCallback onToggleNew,
    required VoidCallback onToggleConfirm,
    required VoidCallback onSave,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: oldController,
              obscureText: !showOld,
              decoration: InputDecoration(
                labelText: 'Mevcut Şifre',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(showOld ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleOld,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: newController,
              obscureText: !showNew,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleNew,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: confirmController,
              obscureText: !showConfirm,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre (Tekrar)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_clock),
                suffixIcon: IconButton(
                  icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleConfirm,
                ),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save),
                label: const Text('Şifreyi Değiştir'),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword1() async {
    setState(() => _error1 = null);

    if (_oldPass1Ctrl.text.isEmpty || _newPass1Ctrl.text.isEmpty || _confirmPass1Ctrl.text.isEmpty) {
      setState(() => _error1 = 'Tüm alanları doldurunuz');
      return;
    }

    if (_newPass1Ctrl.text.length < 4) {
      setState(() => _error1 = 'Yeni şifre en az 4 karakter olmalı');
      return;
    }

    if (_newPass1Ctrl.text != _confirmPass1Ctrl.text) {
      setState(() => _error1 = 'Yeni şifreler eşleşmiyor');
      return;
    }

    final isOldCorrect = await _passwordService.verifyPassword1(_oldPass1Ctrl.text);
    if (!isOldCorrect) {
      setState(() => _error1 = 'Mevcut şifre yanlış');
      return;
    }

    await _passwordService.setPassword1(_newPass1Ctrl.text);

    // Log kaydet
    final user = Session().current;
    if (user != null) {
      await _logsRepo.add(
        subeId: user.subeId,
        calisanId: user.calisanId,
        action: 'SIFRE_DEGISTIR',
        message: 'Şifre 1 (Temel) değiştirildi',
        details: {'level': 1},
      );
    }

    _oldPass1Ctrl.clear();
    _newPass1Ctrl.clear();
    _confirmPass1Ctrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre 1 başarıyla değiştirildi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _changePassword2() async {
    setState(() => _error2 = null);

    if (_oldPass2Ctrl.text.isEmpty || _newPass2Ctrl.text.isEmpty || _confirmPass2Ctrl.text.isEmpty) {
      setState(() => _error2 = 'Tüm alanları doldurunuz');
      return;
    }

    if (_newPass2Ctrl.text.length < 4) {
      setState(() => _error2 = 'Yeni şifre en az 4 karakter olmalı');
      return;
    }

    if (_newPass2Ctrl.text != _confirmPass2Ctrl.text) {
      setState(() => _error2 = 'Yeni şifreler eşleşmiyor');
      return;
    }

    final isOldCorrect = await _passwordService.verifyPassword2(_oldPass2Ctrl.text);
    if (!isOldCorrect) {
      setState(() => _error2 = 'Mevcut şifre yanlış');
      return;
    }

    await _passwordService.setPassword2(_newPass2Ctrl.text);

    // Log kaydet
    final user = Session().current;
    if (user != null) {
      await _logsRepo.add(
        subeId: user.subeId,
        calisanId: user.calisanId,
        action: 'SIFRE_DEGISTIR',
        message: 'Şifre 2 (Yönetici) değiştirildi',
        details: {'level': 2},
      );
    }

    _oldPass2Ctrl.clear();
    _newPass2Ctrl.clear();
    _confirmPass2Ctrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre 2 başarıyla değiştirildi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
