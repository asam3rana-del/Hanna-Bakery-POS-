import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/production_repository.dart';
import '../models/product.dart';
import '../services/session.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import '../widgets/product_picker.dart';

/// Bakery Production: recipes (1 batch mein kitna kacha maal → kitna tayyar maal) aur roz ki tayyari.
///
/// "Bake" dabane par: tayyar item ka stock barhta hai, recipe ke har kache maal (maida, cheeni, anday, ghee...)
/// ka stock ghatta hai — dono Stock History mein (PRODUCTION / USED IN PRODUCTION) aur cloud sync mein.
/// Miqdaar har item ki SMALLEST unit mein (jaise item setup mein hai).
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
String _rs(double v) => 'Rs ${NumberFormat('#,##0').format(v.round())}';

class _ProductionScreenState extends State<ProductionScreen> {
  final _repo = ProductionRepository.instance;
  List<Product> _products = const [];
  Map<String, Product> _byCode = const {};
  List<Recipe> _recipes = const [];
  List<Map<String, Object?>> _log = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await _repo.products();
      final recipes = await _repo.recipes();
      final now = DateTime.now();
      final log = await _repo.log(DateTime(now.year, now.month, now.day - 6), DateTime(now.year, now.month, now.day + 1));
      if (!mounted) return;
      setState(() {
        _products = products;
        _byCode = {for (final p in products) p.barcode: p};
        _recipes = recipes;
        _log = log;
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

  String _name(String code) => _byCode[code]?.name ?? code;
  String _unit(String code) => _byCode[code]?.smallestUnitName() ?? '';

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    if (!Session.isAdminOrManager) {
      return Scaffold(
        appBar: AppBar(title: Text(Loc.t('Production', 'پروڈکشن'))),
        body: Center(child: Text(Loc.t('Only Admin / Manager', 'صرف ایڈمن / منیجر'))),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.navy,
          foregroundColor: Colors.white,
          title: Text(Loc.t('Production', 'پروڈکشن')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: ThemeManager.gold,
            tabs: [
              Tab(text: Loc.t('Bake', 'تیاری')),
              Tab(text: Loc.t('Recipes', 'ریسپیز')),
              Tab(text: Loc.t('Log (7 days)', 'ریکارڈ (7 دن)')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_bakeTab(p), _recipesTab(p), _logTab(p)]),
      ),
    );
  }

  BoxDecoration _box(AppPalette p) => BoxDecoration(
        color: p.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      );

  // ------------------------------------------------------------------ bake

  Widget _bakeTab(AppPalette p) {
    if (_recipes.isEmpty) {
      return _empty(p, Loc.t('No recipes yet. Open the Recipes tab and add one (e.g. 1 batch of bread = 2 kg maida, ...).',
          'ابھی کوئی ریسپی نہیں۔ ریسپیز ٹیب میں شامل کریں (مثلاً ڈبل روٹی کا 1 بیچ = 2 کلو میدہ ...)۔'));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final r in _recipes)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _box(p),
          child: ListTile(
            leading: Icon(Icons.bakery_dining_outlined, color: p.flatAmberFg),
            title: Text(_name(r.barcode), style: TextStyle(fontWeight: FontWeight.bold, color: p.textDark)),
            subtitle: Text(
              '${Loc.t('1 batch', '1 بیچ')} = ${_n(r.yieldQty)} ${_unit(r.barcode)}  •  '
              '${Loc.t('In stock', 'اسٹاک')}: ${_byCode[r.barcode]?.formatStockBreakdown() ?? '-'}',
              style: TextStyle(color: p.textMuted, fontSize: 12.5),
            ),
            trailing: FilledButton(onPressed: () => _bake(r), child: Text(Loc.t('BAKE', 'تیار کریں'))),
          ),
        ),
    ]);
  }

  Future<void> _bake(Recipe r) async {
    final batches = TextEditingController(text: '1');
    final note = TextEditingController();
    var allowShort = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final b = double.tryParse(batches.text.trim()) ?? 0;
        final plan = planProduction(r, b > 0 ? b : 0, _byCode);
        final p = ThemeManager.palette;
        return AlertDialog(
          title: Text('${Loc.t('Bake', 'تیار کریں')}: ${_name(r.barcode)}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: batches,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(labelText: Loc.t('How many batches?', 'کتنے بیچ؟')),
                  onChanged: (_) => setD(() {}),
                ),
                const SizedBox(height: 10),
                Text('${Loc.t('Will make', 'تیار ہوگا')}: ${_n(plan.produce)} ${_unit(r.barcode)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: p.textDark)),
                const SizedBox(height: 8),
                for (final n in plan.needs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text(n.name, style: TextStyle(color: n.short ? p.red : p.textDark))),
                      Text('${_n(n.need)} ${n.unit}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: n.short ? p.red : p.textDark)),
                    ]),
                  ),
                const Divider(),
                Text('${Loc.t('Material cost', 'کچے مال کی لاگت')}: ${_rs(plan.materialCost)}'
                    '${plan.produce > 0 ? '  (${_rs(plan.materialCost / plan.produce)} / ${_unit(r.barcode)})' : ''}'),
                if (plan.anyShort) ...[
                  const SizedBox(height: 8),
                  Text(Loc.t('Some materials are short in stock (red).', 'کچھ کچا مال اسٹاک میں کم ہے (سرخ)۔'),
                      style: TextStyle(color: p.red)),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allowShort,
                    onChanged: (v) => setD(() => allowShort = v ?? false),
                    title: Text(Loc.t('Bake anyway (stock goes minus)', 'پھر بھی تیار کریں (اسٹاک مائنس)'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
                TextField(controller: note, decoration: InputDecoration(labelText: Loc.t('Note (optional)', 'نوٹ (اختیاری)'))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('Cancel', 'منسوخ'))),
            FilledButton(
              onPressed: b > 0 && (!plan.anyShort || allowShort) ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(Loc.t('SAVE', 'محفوظ کریں')),
            ),
          ],
        );
      }),
    );
    final b = double.tryParse(batches.text.trim()) ?? 0;
    final noteText = note.text.trim();
    batches.dispose();
    note.dispose();
    if (ok != true) return;
    try {
      final plan = await _repo.produce(r, b, allowShort: allowShort, note: noteText);
      _toast('${Loc.t('Added to stock', 'اسٹاک میں شامل')}: ${_n(plan.produce)} ${_unit(r.barcode)} ${_name(r.barcode)}');
    } catch (e) {
      _toast(e.toString());
    }
    await _load();
  }

  // ------------------------------------------------------------------ recipes

  Widget _recipesTab(AppPalette p) {
    return Stack(children: [
      _recipes.isEmpty
          ? _empty(p, Loc.t('Tap + to add a recipe', 'ریسپی شامل کرنے کے لیے + دبائیں'))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final r in _recipes)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: _box(p),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text('${_name(r.barcode)}  —  ${_n(r.yieldQty)} ${_unit(r.barcode)} / batch',
                            style: TextStyle(fontWeight: FontWeight.bold, color: p.textDark)),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editRecipe(r)),
                      IconButton(icon: Icon(Icons.delete_outline, color: p.red), onPressed: () => _deleteRecipe(r)),
                    ]),
                    for (final it in r.items)
                      Text('•  ${_name(it.barcode)}: ${_n(it.qty)} ${_unit(it.barcode)}',
                          style: TextStyle(color: p.textMuted, fontSize: 13)),
                    if (r.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(r.note, style: TextStyle(color: p.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                  ]),
                ),
            ]),
      PositionedDirectional(
        end: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          heroTag: 'add_recipe',
          onPressed: () => _editRecipe(null),
          icon: const Icon(Icons.add),
          label: Text(Loc.t('Recipe', 'ریسپی')),
        ),
      ),
    ]);
  }

  Future<void> _deleteRecipe(Recipe r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('${Loc.t('Delete recipe of', 'ریسپی حذف کریں')}: ${_name(r.barcode)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('No', 'نہیں'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(Loc.t('Delete', 'حذف'))),
        ],
      ),
    );
    if (ok != true || r.id == null) return;
    try {
      await _repo.deleteRecipe(r.id!);
    } catch (e) {
      _toast(e.toString());
    }
    await _load();
  }

  Future<void> _editRecipe(Recipe? existing) async {
    if (_products.isEmpty) {
      _toast(Loc.t('Add items first (Items screen)', 'پہلے آئٹمز شامل کریں (آئٹمز اسکرین)'));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _RecipeForm(products: _products, existing: existing, taken: _recipes.map((r) => r.barcode).toSet()),
    ));
    if (saved == true) await _load();
  }

  // ------------------------------------------------------------------ log

  Widget _logTab(AppPalette p) {
    if (_log.isEmpty) return _empty(p, Loc.t('No production in the last 7 days', 'پچھلے 7 دن میں کوئی پروڈکشن نہیں'));
    final f = DateFormat('d MMM, h:mm a');
    final total = _log.fold<double>(0, (a, r) => a + ((r['materialCost'] as num?) ?? 0).toDouble());
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${Loc.t('Material used (7 days)', 'استعمال شدہ کچا مال (7 دن)')}: ${_rs(total)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: p.textDark)),
      const SizedBox(height: 10),
      for (final r in _log)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: _box(p),
          child: ListTile(
            dense: true,
            title: Text(
                '${r['productName']}  +${_n(((r['producedQty'] as num?) ?? 0).toDouble())} ${_unit(r['barcode'] as String)}',
                style: TextStyle(fontWeight: FontWeight.w600, color: p.textDark)),
            subtitle: Text(
              '${f.format(DateTime.fromMillisecondsSinceEpoch((r['createdAt'] as num).toInt()))}  •  '
              '${_n(((r['batches'] as num?) ?? 0).toDouble())} batch  •  ${r['createdBy'] ?? ''}',
              style: TextStyle(color: p.textMuted, fontSize: 12),
            ),
            trailing: Text(_rs(((r['materialCost'] as num?) ?? 0).toDouble()), style: TextStyle(color: p.textDark)),
          ),
        ),
    ]);
  }

  Widget _empty(AppPalette p, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.textMuted)),
        ),
      );
}

// ====================================================================== recipe form

class _Line {
  Product product;
  final TextEditingController qty;
  _Line(this.product, String q) : qty = TextEditingController(text: q);
}

class _RecipeForm extends StatefulWidget {
  const _RecipeForm({required this.products, required this.taken, this.existing});
  final List<Product> products;
  final Set<String> taken;
  final Recipe? existing;

  @override
  State<_RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<_RecipeForm> {
  Product? _finished;
  final _yield = TextEditingController(text: '1');
  final _note = TextEditingController();
  final _lines = <_Line>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      final byCode = {for (final p in widget.products) p.barcode: p};
      _finished = byCode[r.barcode];
      _yield.text = _n(r.yieldQty);
      _note.text = r.note;
      for (final it in r.items) {
        final p = byCode[it.barcode];
        if (p != null) _lines.add(_Line(p, _n(it.qty)));
      }
    }
  }

  @override
  void dispose() {
    _yield.dispose();
    _note.dispose();
    for (final l in _lines) {
      l.qty.dispose();
    }
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickFinished() async {
    final taken = {...widget.taken};
    if (widget.existing != null) taken.remove(widget.existing!.barcode);
    final p = await pickProduct(context, widget.products,
        title: Loc.t('What does this recipe make?', 'یہ ریسپی کیا بناتی ہے؟'), exclude: taken);
    if (p != null && mounted) setState(() => _finished = p);
  }

  Future<void> _addLine() async {
    final exclude = {..._lines.map((l) => l.product.barcode), if (_finished != null) _finished!.barcode};
    final p = await pickProduct(context, widget.products, title: Loc.t('Raw material', 'کچا مال'), exclude: exclude);
    if (p != null && mounted) setState(() => _lines.add(_Line(p, '')));
  }

  Future<void> _save() async {
    if (_saving) return;
    final f = _finished;
    if (f == null) {
      _toast(Loc.t('Choose the finished item', 'تیار آئٹم چنیں'));
      return;
    }
    final y = double.tryParse(_yield.text.trim()) ?? 0;
    final items = <RecipeItem>[];
    for (final l in _lines) {
      final q = double.tryParse(l.qty.text.trim()) ?? 0;
      if (q <= 0) {
        _toast('${Loc.t('Enter quantity for', 'مقدار لکھیں')}: ${l.product.name}');
        return;
      }
      items.add(RecipeItem(l.product.barcode, q));
    }
    setState(() => _saving = true);
    try {
      await ProductionRepository.instance
          .saveRecipe(Recipe(id: widget.existing?.id, barcode: f.barcode, yieldQty: y, note: _note.text.trim(), items: items));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    const kb = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.navy,
        foregroundColor: Colors.white,
        title: Text(widget.existing == null ? Loc.t('New Recipe', 'نئی ریسپی') : Loc.t('Edit Recipe', 'ریسپی میں تبدیلی')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
        Text(Loc.t('FINISHED ITEM', 'تیار آئٹم'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _pickFinished,
          icon: const Icon(Icons.bakery_dining_outlined),
          label: Text(_finished?.name ?? Loc.t('Choose item (e.g. Bread, Rusk, Cake)', 'آئٹم چنیں (مثلاً ڈبل روٹی، رس، کیک)')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _yield,
          keyboardType: kb,
          inputFormatters: numFmt,
          decoration: InputDecoration(
            labelText: Loc.t('1 batch makes', '1 بیچ میں بنتا ہے'),
            suffixText: _finished?.smallestUnitName() ?? '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: Text(Loc.t('RAW MATERIALS PER BATCH', 'فی بیچ کچا مال'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
          ),
          TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: Text(Loc.t('Add', 'شامل'))),
        ]),
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(Loc.t('e.g. Maida 2 kg, Sugar 200 g, Yeast 20 g ...', 'مثلاً میدہ 2 کلو، چینی 200 گرام، خمیر 20 گرام ...'),
                style: TextStyle(color: p.textMuted)),
          ),
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: Text(_lines[i].product.name, style: TextStyle(color: p.textDark))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _lines[i].qty,
                  keyboardType: kb,
                  inputFormatters: numFmt,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: _lines[i].product.smallestUnitName(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: p.red),
                onPressed: () => setState(() {
                  _lines.removeAt(i).qty.dispose();
                }),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: InputDecoration(
            labelText: Loc.t('Note (optional)', 'نوٹ (اختیاری)'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(Loc.t('SAVE RECIPE', 'ریسپی محفوظ کریں')),
          ),
        ),
      ),
    );
  }
}
