import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/wastage_repository.dart';
import '../models/product.dart';
import '../services/permissions.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import '../widgets/product_picker.dart';

/// Bakery Wastage: baasi / kharab / jala hua / bacha hua maal likho — stock ghatta hai aur nuqsan (cost se)
/// aaj / is hafte / is mahine ke hisaab se nazar aata hai. Andar se Stock Adjustment "Damage / Loss" hi hai.
class WastageScreen extends StatefulWidget {
  const WastageScreen({super.key});

  @override
  State<WastageScreen> createState() => _WastageScreenState();
}

enum _Period { today, week, month }

String _rs(double v) => 'Rs ${NumberFormat('#,##0').format(v.round())}';
String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

class _WastageScreenState extends State<WastageScreen> {
  final _repo = WastageRepository.instance;
  _Period _period = _Period.today;
  List<WastageRow> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    return switch (_period) {
      _Period.today => (DateTime(now.year, now.month, now.day), end),
      _Period.week => (DateTime(now.year, now.month, now.day - 6), end),
      _Period.month => (DateTime(now.year, now.month), end),
    };
  }

  Future<void> _load() async {
    final (from, to) = _range();
    try {
      final rows = await _repo.between(from, to);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString());
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _add() async {
    if (!Permissions.can('stock_adjustment')) {
      _toast(Loc.t('Only Admin / Manager can record wastage', 'ویسٹیج صرف ایڈمن / منیجر لکھ سکتا ہے'));
      return;
    }
    List<Product> products;
    try {
      products = await _repo.products();
    } catch (e) {
      _toast(e.toString());
      return;
    }
    if (!mounted) return;
    final product = await pickProduct(context, products, title: Loc.t('Which item is wasted?', 'کون سا آئٹم ضائع ہوا؟'));
    if (product == null || !mounted) return;
    final qty = TextEditingController();
    final note = TextEditingController();
    var reason = WastageReasons.all.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(product.name),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${Loc.t('In stock', 'اسٹاک')}: ${product.formatStockBreakdown()}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: Loc.t('Quantity wasted', 'ضائع مقدار'),
                  suffixText: product.smallestUnitName(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: reason,
                isExpanded: true,
                decoration: InputDecoration(labelText: Loc.t('Reason', 'وجہ')),
                items: [for (final r in WastageReasons.all) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setD(() => reason = v ?? reason),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: InputDecoration(labelText: Loc.t('Note (optional)', 'نوٹ (اختیاری)'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('Cancel', 'منسوخ'))),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(Loc.t('SAVE', 'محفوظ کریں'))),
          ],
        ),
      ),
    );
    final q = double.tryParse(qty.text.trim());
    final noteText = note.text;
    qty.dispose();
    note.dispose();
    if (ok != true) return;
    final err = validateAdjustmentQty(product, q);
    if (err != null) {
      _toast(err);
      return;
    }
    try {
      await _repo.add(product.barcode, q!, reason, note: noteText);
      _toast(Loc.t('Wastage saved — stock reduced', 'ویسٹیج محفوظ — اسٹاک کم ہو گیا'));
    } catch (e) {
      _toast(e.toString());
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final total = _rows.fold<double>(0, (a, r) => a + r.loss);
    // item-wise jama
    final byItem = <String, ({String name, String unit, double qty, double loss})>{};
    for (final r in _rows) {
      final old = byItem[r.movement.barcode];
      byItem[r.movement.barcode] = (
        name: r.name,
        unit: r.unit,
        qty: (old?.qty ?? 0) + r.qty,
        loss: (old?.loss ?? 0) + r.loss,
      );
    }
    final items = byItem.values.toList()..sort((a, b) => b.loss.compareTo(a.loss));
    final f = DateFormat('d MMM, h:mm a');
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.navy,
        foregroundColor: Colors.white,
        title: Text(Loc.t('Wastage', 'ویسٹیج')),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(Loc.t('Add Wastage', 'ویسٹیج لکھیں')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
                SegmentedButton<_Period>(
                  segments: [
                    ButtonSegment(value: _Period.today, label: Text(Loc.t('Today', 'آج'))),
                    ButtonSegment(value: _Period.week, label: Text(Loc.t('7 days', '7 دن'))),
                    ButtonSegment(value: _Period.month, label: Text(Loc.t('This month', 'اس مہینے'))),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    setState(() => _period = s.first);
                    _load();
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.delete_sweep_outlined, color: p.red, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Loc.t('Loss (at cost)', 'نقصان (لاگت پر)'), style: TextStyle(color: p.textMuted)),
                        Text(_rs(total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: p.red)),
                      ]),
                    ),
                    Text('${_rows.length} ${Loc.t('entries', 'اندراج')}', style: TextStyle(color: p.textMuted)),
                  ]),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(Loc.t('BY ITEM', 'آئٹم وار'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
                  const SizedBox(height: 6),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: Text(it.name, style: TextStyle(color: p.textDark))),
                        Text('${_n(it.qty)} ${it.unit}', style: TextStyle(color: p.textMuted)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Text(_rs(it.loss),
                              textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, color: p.textDark)),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 18),
                  Text(Loc.t('ENTRIES', 'اندراجات'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
                  const SizedBox(height: 6),
                  for (final r in _rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                          color: p.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
                      child: ListTile(
                        dense: true,
                        title: Text('${r.name}  −${_n(r.qty)} ${r.unit}',
                            style: TextStyle(fontWeight: FontWeight.w600, color: p.textDark)),
                        subtitle: Text(
                          '${f.format(DateTime.fromMillisecondsSinceEpoch(r.movement.createdAt))}'
                          '${r.movement.note.isEmpty ? '' : '  •  ${r.movement.note}'}',
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                        trailing: Text(_rs(r.loss), style: TextStyle(color: p.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                        child: Text(Loc.t('No wastage recorded', 'کوئی ویسٹیج نہیں لکھی گئی'), style: TextStyle(color: p.textMuted))),
                  ),
              ]),
            ),
    );
  }
}

/// Wastage qty ki jaanch (Stock Adjustment ke "Damage" wale usool).
String? validateAdjustmentQty(Product p, double? qty) {
  if (qty == null || !qty.isFinite || qty <= 0) return Loc.t('Enter a valid quantity', 'صحیح مقدار لکھیں');
  if (!p.isValidSmallestQty(qty)) return 'Miqdaar poori ${p.smallestUnitName()} mein honi chahiye (fraction nahi)';
  return null;
}
