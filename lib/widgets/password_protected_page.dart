import 'package:flutter/material.dart';
import '../services/password_service.dart';

class PasswordProtectedPage extends StatefulWidget {
  final Widget child;
  final bool usePassword2; // true = üst düzey şifre (çalışanlar, şubeler), false = normal şifre (loglar)
  final String title;

  const PasswordProtectedPage({
    super.key,
    required this.child,
    this.usePassword2 = false,
    this.title = 'Korumalı Sayfa',
  });

  @override
  State<PasswordProtectedPage> createState() => _PasswordProtectedPageState();
}

class _PasswordProtectedPageState extends State<PasswordProtectedPage> {
  final _passwordService = PasswordService();
  final _passCtrl = TextEditingController();
  bool _verified = false;
  bool _loading = false;
  String? _error;
  bool _showPassword = false;

  Future<void> _verify() async {
    if (_passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Şifre giriniz');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    
    bool valid;
    if (widget.usePassword2) {
      valid = await _passwordService.verifyPassword2(_passCtrl.text.trim());
    } else {
      valid = await _passwordService.verifyPassword1(_passCtrl.text.trim());
    }
    
    setState(() {
      _loading = false;
      if (valid) {
        _verified = true;
      } else {
        _error = 'Şifre yanlış';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return widget. child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          margin: const EdgeInsets. all(24),
          child: Padding(
            padding:  const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.usePassword2 ? Icons. admin_panel_settings : Icons.lock,
                  size: 64,
                  color: widget.usePassword2 ? Colors.red : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.usePassword2 
                    ? 'Bu sayfa yönetici şifresi gerektirir'
                    : 'Bu sayfa şifre korumalıdır',
                  style:  const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_showPassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.usePassword2 ? 'Yönetici Şifresi' : 'Şifre',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons. lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons. visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = ! _showPassword),
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets. only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color:  Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Devam Et'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}