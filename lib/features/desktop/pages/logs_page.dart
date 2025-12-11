import 'package:flutter/material.dart';
import '../../../data/repositories/logs_repository.dart';
import '../../../models/session.dart';
import '../../../services/password_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _repo = LogsRepository();
  final _q = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  String? _error;
  bool _loading = false;

  // Şifre koruması
  bool _isUnlocked = false;
  final _passwordController = TextEditingController();
  String? _passwordError;

  // Filtreler
  String _filterAction = 'Tümü';
  String _filterRelatedType = 'Tümü';
  List<String> _actions = ['Tümü'];
  List<String> _relatedTypes = ['Tümü'];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _passwordError = 'Şifre giriniz');
      return;
    }
    final isValid =
        await PasswordService.verifyPassword1(_passwordController.text.trim());
    if (isValid) {
      setState(() {
        _isUnlocked = true;
        _passwordError = null;
      });
      _load();
    } else {
      setState(() => _passwordError = 'Şifre yanlış');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
      _items = [];
    });
    try {
      _items =
          await _repo.listByBranch(Session().current!.subeId, q: _q.text.trim());

      final actionSet = <String>{'Tümü'};
      final typeSet = <String>{'Tümü'};
      for (final m in _items) {
        final action = (m['ACTION'] ?? '').toString();
        final type = (m['RELATED_TYPE'] ?? '').toString();
        if (action.isNotEmpty) actionSet.add(action);
        if (type.isNotEmpty) typeSet.add(type);
      }
      _actions = actionSet.toList()..sort();
      _relatedTypes = typeSet.toList()..sort();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((m) {
      if (_filterAction != 'Tümü') {
        final action = (m['ACTION'] ?? '').toString();
        if (action != _filterAction) return false;
      }
      if (_filterRelatedType != 'Tümü') {
        final type = (m['RELATED_TYPE'] ?? '').toString();
        if (type != _filterRelatedType) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildPasswordScreen();
    }

    final filtered = _filteredItems;

    return Row(children: [
      Expanded(
          flex: 2,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _q,
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Log ara... '),
                          onSubmitted: (_) => _load())),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _load, child: const Text('Yenile')),
                ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Filtreler:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Aksiyon: '),
                    DropdownButton<String>(
                      value: _actions.contains(_filterAction)
                          ? _filterAction
                          : 'Tümü',
                      items: _actions
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _filterAction = v ?? 'Tümü');
                      },
                    ),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Tür: '),
                    DropdownButton<String>(
                      value: _relatedTypes.contains(_filterRelatedType)
                          ? _filterRelatedType
                          : 'Tümü',
                      items: _relatedTypes
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _filterRelatedType = v ?? 'Tümü');
                      },
                    ),
                  ]),
                  Text('${filtered.length} / ${_items.length} kayıt',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Hata: $_error'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final m = filtered[i];
                              return Card(
                                  child: ListTile(
                                leading: const Icon(Icons.event_note),
                                title: Text(
                                    '${m['ACTION']} • ${m['MESSAGE']}'),
                                subtitle: Text(
                                    '${m['CREATED_AT']} • ${m['RELATED_TYPE'] ?? '-'}#${m['RELATED_ID'] ?? '-'}'),
                                onTap: () =>
                                    setState(() => _selected = m),
                              ));
                            }))
          ])),
      const VerticalDivider(width: 1),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log Detayı',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_selected == null)
                      const Text('Listeden bir log seçiniz')
                    else ...[
                      _buildDetailRow('Aksiyon', '${_selected!['ACTION']}'),
                      _buildDetailRow('Mesaj', '${_selected!['MESSAGE']}'),
                      _buildDetailRow(
                          'İlgili Tür', '${_selected!['RELATED_TYPE'] ?? '-'}'),
                      _buildDetailRow(
                          'İlgili ID', '${_selected!['RELATED_ID'] ?? '-'}'),
                      _buildDetailRow(
                          'Tarih', '${_selected!['CREATED_AT']}'),
                      _buildDetailRow(
                          'Şube ID', '${_selected!['SUBE_ID'] ?? '-'}'),
                      _buildDetailRow('Çalışan ID',
                          '${_selected!['CALISAN_ID'] ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Detaylar:',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                            '${_selected!['DETAILS'] ?? '-'}'),
                      ),
                    ],
                  ]))),
    ]);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ]),
    );
  }

  Widget _buildPasswordScreen() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 64, color: Colors.indigo),
                const SizedBox(height: 16),
                Text('Log Girişi',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                    'Loglar sayfasına erişmek için uygulama şifresi gereklidir.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Uygulama Şifresi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _verifyPassword(),
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 8),
                  Text(_passwordError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _verifyPassword,
                    child: const Text('Giriş'),
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