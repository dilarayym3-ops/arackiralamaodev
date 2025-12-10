import 'package:flutter/material.dart';
import '../../../data/repositories/payment_repository.dart' as pay;
import '../../../data/repositories/rental_repository.dart' as rent;
import '../../../widgets/payment_type_dialog.dart';
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

  // ödenmiş/ödenmemiş belirgin rozet - PAY_STATUS sütununu kullan
  String _payStatus(Map<String, dynamic> m) {
    return (m['PAY_STATUS'] ?? 'Yok') as String;
  }
  
  Color _statusColor(String s) {
    switch (s) {
      case 'Ödendi':
        return const Color(0xFF4CAF50); // Yeşil
      case 'Kısmi':
        return const Color(0xFFFF9800); // Turuncu
      default:
        return const Color(0xFFF44336); // Kırmızı
    }
  }
  
  IconData _statusIcon(String s) {
    switch (s) {
      case 'Ödendi':
        return Icons.check_circle;
      case 'Kısmi':
        return Icons.hourglass_bottom;
      default:
        return Icons.cancel;
    }
  }

  Future<void> _makePayment(Map<String, dynamic> m) async {
    // Ödenmemiş veya kısmi ödenmiş kayıt için ödeme yap
    final paymentType = await PaymentTypeDialog.show(
      context: context,
      title: 'Ödeme Tipi Seçin',
    );
    
    if (paymentType == null) return; // İptal edildi
    
    // Kalanı hesapla ve ödeme yap
    final cezaId = m['CEZA_ID'] as int?;
    final sigortaId = m['SIGORTA_ID'] as int?;
    final bakimId = m['BAKIM_ID'] as int?;
    final kazaId = m['KAZA_ID'] as int?;
    
    try {
      // İlgili türe göre ödeme ekle
      if (cezaId != null) {
        final totalTarget = (m['TOTAL_TARGET'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (m['TOTAL_PAID'] as num?)?.toDouble() ?? 0.0;
        final kalan = totalTarget - totalPaid;
        if (kalan > 0) {
          await _repo.add(cezaId: cezaId, tutar: kalan, tur: 'Ceza', tipi: paymentType);
          _sn('Ceza için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
        }
      } else if (sigortaId != null) {
        final totalTarget = (m['TOTAL_TARGET'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (m['TOTAL_PAID'] as num?)?.toDouble() ?? 0.0;
        final kalan = totalTarget - totalPaid;
        if (kalan > 0) {
          await _repo.add(sigortaId: sigortaId, tutar: kalan, tur: 'Sigorta', tipi: paymentType);
          _sn('Sigorta için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
        }
      } else if (bakimId != null) {
        final totalTarget = (m['TOTAL_TARGET'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (m['TOTAL_PAID'] as num?)?.toDouble() ?? 0.0;
        final kalan = totalTarget - totalPaid;
        if (kalan > 0) {
          await _repo.add(bakimId: bakimId, tutar: kalan, tur: 'Bakım', tipi: paymentType);
          _sn('Bakım için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
        }
      } else if (kazaId != null) {
        final totalTarget = (m['TOTAL_TARGET'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (m['TOTAL_PAID'] as num?)?.toDouble() ?? 0.0;
        final kalan = totalTarget - totalPaid;
        if (kalan > 0) {
          await _repo.add(kazaId: kazaId, tutar: kalan, tur: 'Kaza', tipi: paymentType);
          _sn('Kaza için ${kalan.toStringAsFixed(2)} TL ödeme eklendi ($paymentType)');
        }
      }
      await _load();
    } catch (e) {
      _err(e);
    }
  }

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
              final tutar = (m['ODEME_TUTARI'] as num?)?.toDouble() ?? 0.0;
              final status = _payStatus(m);
              final statusColor = _statusColor(status);
              
              // Kalan tutar hesapla
              final totalTarget = (m['TOTAL_TARGET'] as num?)?.toDouble();
              final totalPaid = (m['TOTAL_PAID'] as num?)?.toDouble() ?? 0.0;
              final hasUnpaid = totalTarget != null && totalPaid < totalTarget;
              final kalan = totalTarget != null ? totalTarget - totalPaid : 0.0;
              
              return Card(child: ListTile(
                leading: Icon(_statusIcon(status), color: statusColor, size: 32),
                title: Text('Ödeme#${m['ODEME_ID']} • ${m['PLAKA'] ?? '-'} • ${m['Marka'] ?? '-'} ${m['Model'] ?? ''}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tür: $label • Tip: $tip • Tutar: ${tutar.toStringAsFixed(2)} TL'),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          status == 'Yok' ? 'ÖDENMEDİ' : status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      if (totalTarget != null) ...[
                        const SizedBox(width: 8),
                        Text('Hedef: ${totalTarget.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('Toplam: ${totalPaid.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 12)),
                        if (kalan > 0) ...[
                          const SizedBox(width: 8),
                          Text('Kalan: ${kalan.toStringAsFixed(2)} TL', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ]),
                  ],
                ),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton.icon(onPressed: () => _fill(m), icon: const Icon(Icons.edit, size: 18), label: const Text('Düzenle')),
                  if (hasUnpaid && kalan > 0)
                    FilledButton.icon(
                      onPressed: () => _makePayment(m),
                      icon: const Icon(Icons.payments, size: 18),
                      label: const Text('Öde'),
                    ),
                ]),
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