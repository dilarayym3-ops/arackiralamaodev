import 'package:flutter/material.dart';
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../data/repositories/rental_repository.dart' as rent;
import '../../../models/session.dart';

class PaymentsPage extends StatefulWidget { const PaymentsPage({super.key}); @override State<PaymentsPage> createState() => _PaymentsPageState(); }
class _PaymentsPageState extends State<PaymentsPage> {
  final _repo = pay.PaymentRepository();
  final _rentalRepo = rent.RentalRepository();

  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  final upTutar = TextEditingController();
  String upTur = 'Kira';
  String upTip = 'Nakit';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _selected = null; });
    try { _items = await _repo.listByBranch(Session().current!.subeId, q: _q.text.trim()); }
    catch (e) { _error = e.toString(); } finally { setState(() => _loading = false); }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    try { await _repo.delete(_selected!['ODEME_ID'] as int); setState(() => _selected = null); _sn('Ödeme silindi'); await _load(); }
    catch (e) { _err(e); }
  }

  Future<void> _update() async {
    if (_selected == null) return;
    try {
      await _repo.update(
        odemeId: _selected!['ODEME_ID'] as int,
        tutar: double.tryParse(upTutar.text),
        tur: upTur,
        tipi: upTip,
      );
      _sn('Ödeme güncellendi'); await _load();
    } catch (e) { _err(e); }
  }

  void _fill(Map<String, dynamic> m) {
    _selected = m;
    upTutar.text = (m['ODEME_TUTARI'] ?? '').toString();
    upTur = (m['ODEME_TURU'] ?? 'Kira').toString();
    upTip = (m['ODEME_TIPI'] ?? 'Nakit').toString();
    setState(() {});
  }

  // ödenmiş/ödenmemiş belirgin rozet
  String _payStatus(Map<String, dynamic> m) {
    // burada basitçe "Kampanya/Diğer" tipleri için "Bekleyen" gibi düşünebiliriz;
    // kesin hesaplama gerektiriyorsa kiralama/sigorta/bakım ceza tutarlarına göre ayrıştırma yapılır.
    final tip = (m['ODEME_TIPI'] ?? '') as String;
    if (tip.toLowerCase() == 'kampanya' || tip.toLowerCase() == 'diğer' || tip.toLowerCase() == 'diger') return 'Bekleyen';
    return 'Ödenmiş';
  }
  Color _statusColor(String s) => s == 'Bekleyen' ? Colors.orange : Colors.green;

  void _sn(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _err(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _q, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ödeme/Plaka/Model/Kiralama ara...'), onSubmitted: (_) => _load())),
          const SizedBox(width: 8), FilledButton(onPressed: _load, child: const Text('Yenile')),
        ])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Hata: $_error')) :
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = _items[i];
              final label = (m['ODEME_TURU'] ?? '-') as String;
              final tip = (m['ODEME_TIPI'] ?? '-') as String;
              final tutar = (m['ODEME_TUTARI'] ?? '-') .toString();
              final status = _payStatus(m);
              final color = _statusColor(status);
              return Card(child: ListTile(
                leading: const Icon(Icons.payments),
                title: Text('Ödeme#${m['ODEME_ID']} • ${m['PLAKA'] ?? '-'} • ${m['Marka'] ?? '-'} ${m['Model'] ?? ''}'),
                subtitle: Text('Tür: $label • Tip: $tip • Tutar: $tutar'),
                trailing: Chip(label: Text(status), backgroundColor: color.withOpacity(0.1), labelStyle: TextStyle(color: color)),
                onTap: () => _fill(m),
              ));
            },
          ),
        ),
      ])),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ödeme Detay', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_selected == null) const Text('Listeden bir ödeme seçin') else Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ID: ${_selected!['ODEME_ID']}'),
          const SizedBox(height: 8),
          TextField(controller: upTutar, decoration: const InputDecoration(labelText: 'Tutar (TL)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: upTur, items: const [
            DropdownMenuItem(value: 'Kira', child: Text('Kira')),
            DropdownMenuItem(value: 'Depozito', child: Text('Depozito')),
            DropdownMenuItem(value: 'İade', child: Text('İade')),
            DropdownMenuItem(value: 'Ceza', child: Text('Ceza')),
            DropdownMenuItem(value: 'Sigorta', child: Text('Sigorta')),
            DropdownMenuItem(value: 'Bakım', child: Text('Bakım')),
            DropdownMenuItem(value: 'Kaza', child: Text('Kaza')),
            DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
          ], onChanged: (v) => setState(() => upTur = v ?? upTur), decoration: const InputDecoration(labelText: 'Tür')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: upTip, items: const [
            DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
            DropdownMenuItem(value: 'Kart', child: Text('Kart')),
            DropdownMenuItem(value: 'Havale', child: Text('Havale')),
            DropdownMenuItem(value: 'Kampanya', child: Text('Kampanya')),
            DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
          ], onChanged: (v) => setState(() => upTip = v ?? upTip), decoration: const InputDecoration(labelText: 'Tip')),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton(onPressed: _update, child: const Text('Güncelle')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _delete, child: const Text('Sil')),
          ]),
        ]),
      ]))),
    ]);
  }
}