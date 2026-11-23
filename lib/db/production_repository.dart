import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/session.dart';
import '../sync/sync_queue_helper.dart';
import 'app_database.dart';
import 'product_repository.dart';
import 'stock_ledger.dart';
import 'unit_cost.dart';

/// Stock ledger types jo production likhti hai.
class ProductionMovement {
  ProductionMovement._();
  static const made = MovementType.production; // tayyar maal (+)
  static const used = MovementType.productionUse; // kacha maal istemal (-)
}

class ProductionException implements Exception {
  final String message;
  const ProductionException(this.message);
  @override
  String toString() => message;
}

/// Recipe ki ek line: kacha maal + ek batch mein kitna (product ki SMALLEST unit mein).
class RecipeItem {
  final String barcode;
  final double qty;
  const RecipeItem(this.barcode, this.qty);
}

/// Ek tayyar product ki recipe: ek batch mein [yieldQty] (smallest unit) banta hai.
class Recipe {
  final int? id;
  final String barcode;
  final double yieldQty;
  final String note;
  final List<RecipeItem> items;
  const Recipe({this.id, required this.barcode, required this.yieldQty, this.note = '', this.items = const []});
}

/// Production plan ki ek line (pure hisaab — test ke liye).
class ProductionNeed {
  final String barcode;
  final String name;
  final String unit;
  final double need;
  final double inStock;
  final double cost;
  const ProductionNeed({
    required this.barcode,
    required this.name,
    required this.unit,
    required this.need,
    required this.inStock,
    required this.cost,
  });
  bool get short => need > inStock + 1e-9;
}

class ProductionPlan {
  final double produce; // tayyar maal (smallest unit)
  final List<ProductionNeed> needs;
  const ProductionPlan(this.produce, this.needs);
  double get materialCost => needs.fold(0.0, (a, n) => a + n.cost);
  bool get anyShort => needs.any((n) => n.short);
  List<ProductionNeed> get shortages => needs.where((n) => n.short).toList();
}

/// Pure: [batches] ke liye kitna kacha maal chahiye aur kitni laagat.
ProductionPlan planProduction(Recipe r, double batches, Map<String, Product> products) {
  final needs = <ProductionNeed>[];
  for (final it in r.items) {
    final p = products[it.barcode];
    final need = it.qty * batches;
    needs.add(ProductionNeed(
      barcode: it.barcode,
      name: p?.name ?? it.barcode,
      unit: p?.smallestUnitName() ?? '',
      need: need,
      inStock: p?.stock ?? 0,
      cost: p == null ? 0 : need * costPerSmallestOf(p.cost, p.smallestUnitFactor()),
    ));
  }
  return ProductionPlan(r.yieldQty * batches, needs);
}

/// Recipes + roz ki production. Production: tayyar product ka stock (+), har kache maal ka stock (-),
/// dono stock ledger (Stock History) mein, aur product stock sync hota hai — ek hi transaction mein.
class ProductionRepository {
  ProductionRepository._();
  static final ProductionRepository instance = ProductionRepository._();

  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Product>> products() async {
    final rows = await (await _db).query('products', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Recipe>> recipes() async {
    final db = await _db;
    final rs = await db.query('recipes', orderBy: 'id ASC');
    final items = await db.query('recipe_items', orderBy: 'id ASC');
    final byRecipe = <int, List<RecipeItem>>{};
    for (final i in items) {
      byRecipe
          .putIfAbsent((i['recipeId'] as num).toInt(), () => [])
          .add(RecipeItem(i['barcode'] as String, (i['qty'] as num).toDouble()));
    }
    return rs.map((r) {
      final id = (r['id'] as num).toInt();
      return Recipe(
        id: id,
        barcode: r['barcode'] as String,
        yieldQty: (r['yieldQty'] as num).toDouble(),
        note: (r['note'] as String?) ?? '',
        items: byRecipe[id] ?? const [],
      );
    }).toList();
  }

  /// Recipe save (naya ya purana — tayyar product ke barcode se pehchana jata hai).
  Future<void> saveRecipe(Recipe r) async {
    if (!Session.isAdminOrManager) throw const ProductionException('Recipe sirf Admin/Manager bana sakta hai');
    if (!r.yieldQty.isFinite || r.yieldQty <= 0) throw const ProductionException('Ek batch mein kitna banta hai — likhen');
    if (r.items.isEmpty) throw const ProductionException('Kam az kam ek kacha maal shamil karein');
    for (final it in r.items) {
      if (it.barcode == r.barcode) throw const ProductionException('Product apni hi recipe mein nahi aa sakta');
      if (!it.qty.isFinite || it.qty <= 0) throw const ProductionException('Har kache maal ki miqdaar likhen');
    }
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final existing = await txn.query('recipes', where: 'barcode=?', whereArgs: [r.barcode], limit: 1);
      int id;
      if (existing.isEmpty) {
        id = await txn.insert('recipes', {'barcode': r.barcode, 'yieldQty': r.yieldQty, 'note': r.note, 'updatedAt': now});
      } else {
        id = (existing.first['id'] as num).toInt();
        await txn.update('recipes', {'yieldQty': r.yieldQty, 'note': r.note, 'updatedAt': now},
            where: 'id=?', whereArgs: [id]);
        await txn.delete('recipe_items', where: 'recipeId=?', whereArgs: [id]);
      }
      for (final it in r.items) {
        await txn.insert('recipe_items', {'recipeId': id, 'barcode': it.barcode, 'qty': it.qty});
      }
    });
  }

  Future<void> deleteRecipe(int id) async {
    if (!Session.isAdminOrManager) throw const ProductionException('Sirf Admin/Manager');
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('recipe_items', where: 'recipeId=?', whereArgs: [id]);
      await txn.delete('recipes', where: 'id=?', whereArgs: [id]);
    });
  }

  /// [batches] banao. [allowShort] = kacha maal kam ho tab bhi (stock minus mein chala jaye).
  Future<ProductionPlan> produce(Recipe r, double batches, {bool allowShort = false, String note = ''}) async {
    if (!Session.isAdminOrManager) throw const ProductionException('Production sirf Admin/Manager likh sakta hai');
    if (!batches.isFinite || batches <= 0) throw const ProductionException('Batch ki ginti likhen');
    final db = await _db;
    late ProductionPlan plan;
    await db.transaction((txn) async {
      final barcodes = {r.barcode, ...r.items.map((i) => i.barcode)}.toList();
      final rows = await txn.query('products',
          where: 'barcode IN (${List.filled(barcodes.length, '?').join(',')})', whereArgs: barcodes);
      final byCode = {for (final m in rows) m['barcode'] as String: Product.fromMap(m)};
      final finished = byCode[r.barcode];
      if (finished == null) throw const ProductionException('Tayyar product nahi mila (shayad delete ho gaya)');
      for (final it in r.items) {
        if (!byCode.containsKey(it.barcode)) {
          throw ProductionException('Kacha maal nahi mila: ${it.barcode} — recipe theek karein');
        }
      }
      plan = planProduction(r, batches, byCode);
      if (plan.anyShort && !allowShort) {
        final s = plan.shortages.map((n) => n.name).join(', ');
        throw ProductionException('Kacha maal kam hai: $s');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = 'production-$now';
      for (final n in plan.needs) {
        if (n.need <= 0) continue;
        await txn.rawUpdate('UPDATE products SET stock = stock - ?, dirty = 1, updatedAt = ? WHERE barcode = ?',
            [n.need, now, n.barcode]);
        await StockLedger.log(txn,
            barcode: n.barcode,
            type: ProductionMovement.used,
            signedQty: -n.need,
            reference: ref,
            unitCost: byCode[n.barcode]!.cost,
            note: 'Production: ${finished.name}',
            now: now);
        await SyncQueueHelper.enqueueStockDelta(txn, n.barcode, -n.need);
      }
      await txn.rawUpdate('UPDATE products SET stock = stock + ?, dirty = 1, updatedAt = ? WHERE barcode = ?',
          [plan.produce, now, r.barcode]);
      await StockLedger.log(txn,
          barcode: r.barcode,
          type: ProductionMovement.made,
          signedQty: plan.produce,
          reference: ref,
          unitCost: finished.cost,
          note: note.isEmpty ? 'Production ${_n(batches)} batch' : note,
          now: now);
      await SyncQueueHelper.enqueueStockDelta(txn, r.barcode, plan.produce);
      await txn.insert('production_log', {
        'recipeId': r.id ?? 0,
        'barcode': r.barcode,
        'productName': finished.name,
        'batches': batches,
        'producedQty': plan.produce,
        'materialCost': plan.materialCost,
        'note': note,
        'createdBy': Session.username ?? '',
        'createdAt': now,
      });
    });
    await ProductionRepository._refreshProducts();
    return plan;
  }

  /// Production log (naya pehle) — [from]..[to].
  Future<List<Map<String, Object?>>> log(DateTime from, DateTime to) async {
    return (await _db).query('production_log',
        where: 'createdAt >= ? AND createdAt < ?',
        whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        orderBy: 'createdAt DESC, id DESC');
  }

  static Future<void> _refreshProducts() async {
    try {
      await ProductRepository.instance.refresh();
    } catch (_) {}
  }

  static String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
}
