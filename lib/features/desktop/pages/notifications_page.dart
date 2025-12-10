import 'package:flutter/material.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../../models/session.dart';
import '../../../models/ui_router.dart';

class NotificationsPage extends StatefulWidget { const NotificationsPage({super.key}); @override State<NotificationsPage> createState() => _NotificationsPageState(); }
class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = NotificationsRepository();
  final _q = TextEditingController();
  bool _onlyUnread = true;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  String? _error;
  bool _loading = false;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; _items = []; });
    try {
      final rows = await _repo.listByBranch(Session().current!.subeId, onlyUnread: _onlyUnread, q: _q.text.trim());
      setState(() => _items = rows);
      await _refreshUnreadBadge();
    } catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  @override void initState() { super.initState(); _load(); }

  Future<void> _refreshUnreadBadge() async {
    final rows = await _repo.listByBranch(Session().current!.subeId, onlyUnread: true);
    UiRouter().setUnread(rows.length);
  }

  void _goToRelated(Map<String, dynamic> m) async {
    // Okundu işaretle ve rozet güncelle
    await _repo.markRead(m['NOTIF_ID'] as int, read: true);
    await _refreshUnreadBadge();

    final type = (m['RELATED_TYPE'] ?? '').toString().toUpperCase();
    final router = UiRouter();
    switch (type) {
      case 'REZERVASYON': router.go(2, max: 15); break;
      case 'KIRALAMA': router.go(5, max: 15); break;
      case 'CEZA': router.go(3, max: 15); break;
      case 'ODEME': router.go(11, max: 15); break;
      case 'SIGORTA': router.go(4, max: 15); break;
      case 'BAKIM': router.go(10, max: 15); break;
      case 'KAZA': router.go(12, max: 15); break;
      default: break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Bildirim ara...'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8),
          Row(children: [ Checkbox(value: _onlyUnread, onChanged: (v) => setState(() => _onlyUnread = v ?? true)), const Text('Sadece okunmamış') ]),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(padding: const EdgeInsets.all(12), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
            final m = _items[i];
            final read = (m['IS_READ'] == 1 || m['IS_READ'] == true);
            return Card(child: ListTile(
              leading: Icon(read ? Icons.notifications : Icons.notification_important, color: read ? Colors.indigo : Colors.orange),
              title: Text('${m['CATEGORY']} • ${m['MESSAGE']}'),
              subtitle: Text('${m['CREATED_AT']} • ${m['RELATED_TYPE'] ?? '-'}#${m['RELATED_ID'] ?? '-'}'),
              selected: _selected?['NOTIF_ID'] == m['NOTIF_ID'],
              onTap: () async { setState(() => _selected = m); await _repo.markRead(m['NOTIF_ID'] as int, read: true); await _refreshUnreadBadge(); },
            ));
          })
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bildirim Detay', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_selected == null) const Text('Listeden bir bildirim seçiniz')
          else ...[
            Text('Kategori: ${_selected!['CATEGORY']}'),
            Text('Mesaj: ${_selected!['MESSAGE']}'),
            Text('İlgili: ${_selected!['RELATED_TYPE'] ?? '-'}#${_selected!['RELATED_ID'] ?? '-'}'),
            Text('Tarih: ${_selected!['CREATED_AT']}'),
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(onPressed: () => _goToRelated(_selected!), icon: const Icon(Icons.open_in_new), label: const Text('İlgiline Git')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () async { await _repo.delete(_selected!['NOTIF_ID'] as int); await _load(); }, icon: const Icon(Icons.delete), label: const Text('Sil')),
            ]),
          ],
        ],
      ))),
    ]);
  }
}