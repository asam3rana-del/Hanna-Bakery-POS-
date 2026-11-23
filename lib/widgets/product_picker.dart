import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';

/// Bakery screens (Production / Wastage) ka saada product chunao: search + list. null = band kiya.
Future<Product?> pickProduct(BuildContext context, List<Product> products, {String? title, Set<String> exclude = const {}}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProductPickerSheet(
      products: products.where((p) => !exclude.contains(p.barcode)).toList(),
      title: title ?? Loc.t('Choose item', 'آئٹم چنیں'),
    ),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products, required this.title});
  final List<Product> products;
  final String title;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.products
        : widget.products
            .where((x) => x.matchesQuery(q) || x.barcode.toLowerCase().contains(q) || x.category.toLowerCase().contains(q))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: p.textDark)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: Loc.t('Search item name / barcode', 'آئٹم کا نام / بارکوڈ تلاش کریں'),
                filled: true,
                fillColor: p.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(Loc.t('No items found', 'کوئی آئٹم نہیں ملا'), style: TextStyle(color: p.textMuted)))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
                    itemBuilder: (_, i) {
                      final x = list[i];
                      return ListTile(
                        title: Text(x.name, style: TextStyle(color: p.textDark, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${Loc.t('Stock', 'اسٹاک')}: ${x.formatStockBreakdown()}'
                          '${x.category.isEmpty ? '' : '  •  ${x.category}'}',
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                        onTap: () => Navigator.of(context).pop(x),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
