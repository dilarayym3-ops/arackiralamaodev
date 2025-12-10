import 'package:flutter/material.dart';
import '../../../data/repositories/rental_repository.dart';
import '../../../models/session.dart';
import '../../../models/ui_router.dart';

String fmtDate(Object? v) {
  if (v == null) return '-';
  final s = v.toString();
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

class HistoryPage extends StatefulWidget { const HistoryPage({super.key}); @override State<HistoryPage> createState() => _HistoryPageState(); }
class _HistoryPageState extends State<HistoryPage> {
  final _repo = RentalRepository();
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  String? _error; bool _loading = false;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _items = []; _selected = null; });
    try { _items = await _repo.listBySube(Session().current!.subeId, durum: 'Tümü'); }
    catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  @override void initState() { super.initState(); _load(); }

  bool _ongoing(Map<String,dynamic> m) => m['GERCEKLESEN_TESLIM_TARIHI'] == null;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kiralama/Plaka/Model ara...'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Yenile')),
          const Spacer(), TextButton.icon(onPressed: () => UiRouter().go(0), icon: const Icon(Icons.home, color: Colors.indigo), label: const Text('Ana Ekran')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(padding: const EdgeInsets.all(12), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
            final m = _items[i];
            final ongoing = _ongoing(m);
            return Card(child: ListTile(
              leading: Icon(ongoing ? Icons.timer : Icons.history, color: ongoing ? Colors.orange : null),
              title: Text('Kiralama #${m['KIRALAMA_ID']} • ${m['PLAKA']} • ${m['Marka']} ${m['Model']} • Alış KM: ${m['ALIS_KM']}'),
              subtitle: Text('Alış: ${fmtDate(m['ALIS_TARIHI'])} • Plan Teslim: ${fmtDate(m['PLANLANAN_TESLIM_TARIHI'])} • Gerçek Teslim: ${fmtDate(m['GERCEKLESEN_TESLIM_TARIHI'])} • Toplam: ${m['TOPLAM_KIRA_TUTARI'] ?? '-'}'),
              onTap: () => setState(() => _selected = m),
            ));
          })
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Kiralama Detayı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_selected == null) const Text('Listeden bir kiralama seçiniz')
        else ...[
          Text('Kiralama ID: ${_selected!['KIRALAMA_ID']}'),
          Text('Araç: ${_selected!['PLAKA']} • ${_selected!['Marka']} ${_selected!['Model']}'),
          Text('Alış: ${fmtDate(_selected!['ALIS_TARIHI'])} • Plan Teslim: ${fmtDate(_selected!['PLANLANAN_TESLIM_TARIHI'])}'),
          Text('Gerçek Teslim: ${fmtDate(_selected!['GERCEKLESEN_TESLIM_TARIHI'])}'),
          Text('KM: Alış ${_selected!['ALIS_KM']} • Dönüş ${_selected!['DONUS_KM'] ?? '-'}'),
          Text('Toplam Kira Tutarı: ${_selected!['TOPLAM_KIRA_TUTARI'] ?? '-'}'),
        ],
      ]))),
    ]);
  }
}