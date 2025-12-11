import 'package:flutter/material.dart';
import '../services/password_service.dart';

class PasswordDialog extends StatefulWidget {
  final bool isAdmin;
  final String title;
  final String description;

  const PasswordDialog({
    super.key,
    this.isAdmin = false,
    required this.title,
    required this.description,
  });

  static Future<bool> show(
    BuildContext context, {
    bool isAdmin = false,
    String?  title,
    String? description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordDialog(
        isAdmin: isAdmin,
        title: title ?? (isAdmin ? 'Yönetici Şifresi Gerekli' : 'Şifre Gerekli'),
        description: description ?? (isAdmin 
            ? 'Bu sayfaya erişmek için yönetici şifresini girin.'
            : 'Devam etmek için şifrenizi girin.'),
      ),
    );
    return result ??  false;
  }

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _ctrl = TextEditingController();
  final _passwordService = PasswordService();
  bool _show = false;
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    if (_ctrl.text.isEmpty) {
      setState(() => _error = 'Şifre boş olamaz');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await _passwordService.verifyPassword(_ctrl.text, isAdmin: widget.isAdmin);
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Şifre yanlış');
      }
    } catch (e) {
      setState(() => _error = 'Hata:  $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isAdmin ? Colors.deepOrange : Colors.blue;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: color),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: !_show,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _verify,
          style: FilledButton.styleFrom(backgroundColor: color),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Giriş'),
        ),
      ],
    );
  }
}