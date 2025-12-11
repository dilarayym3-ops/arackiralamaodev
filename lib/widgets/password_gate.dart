import 'package:flutter/material.dart';
import '../services/password_service.dart';

enum PasswordLevel { app, admin }

class PasswordGate extends StatefulWidget {
  final Widget child;
  final PasswordLevel level;
  final String title;

  const PasswordGate({
    super.key,
    required this. child,
    required this.level,
    this.title = 'Şifre Gerekli',
  });

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final _passwordService = PasswordService();
  final _controller = TextEditingController();
  bool _verified = false;
  bool _loading = false;
  bool _obscure = true;
  String?  _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final password = _controller.text. trim();
    if (password.isEmpty) {
      setState(() {
        _error = 'Şifre giriniz';
        _loading = false;
      });
      return;
    }

    bool isValid;
    if (widget.level == PasswordLevel.admin) {
      isValid = await _passwordService.verifyAdminPassword(password);
    } else {
      isValid = await _passwordService.verifyAppPassword(password);
    }

    if (isValid) {
      setState(() {
        _verified = true;
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Şifre yanlış';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return widget.child;
    }

    final levelText = widget.level == PasswordLevel.admin ?  'Yönetici Şifresi' : 'Uygulama Şifresi';

    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child:  Column(
              mainAxisSize:  MainAxisSize.min,
              children: [
                Icon(
                  widget.level == PasswordLevel.admin ?  Icons.admin_panel_settings : Icons.lock,
                  size: 64,
                  color: widget. level == PasswordLevel.admin ?  Colors.orange : Colors.indigo,
                ),
                const SizedBox(height: 16),
                Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Bu sayfaya erişmek için $levelText gereklidir.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: levelText,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility :  Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width:  double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child:  CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Giriş'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}