import '../models/product.dart';
import '../models/stock_movement.dart';
import 'app_database.dart';
import 'stock_adjustment_repository.dart';
import 'unit_cost.dart';

/// Bakery wastage = bacha hua / baasi / kharab maal. Stock Adjustment ka "Damage / Loss" hi istemal hota hai
/// (stock ghatata hai, ledger type DAMAGE), is liye Stock History, Stock Audit aur Inventory Insights sab mein
/// khud nazar aata hai. Yahan sirf tez entry + din / mahine ka nuqsan.
class WastageReasons {
  WastageReasons._();
  static const all = <String>[
    'Baasi / expiry (stale)',
    'Toot gaya / kharab (damaged)',
    'Jal gaya (burnt)',
    'Bacha hua maal (unsold)',
    'Customer wapsi (returned)',
    'Staff / sample',
    'Other',
  ];
}

class WastageRow {
  final StockMovement movement;
  final String name;
  final String unit;
  final double loss; // Rs (us waqt ki cost se)
  const WastageRow(this.movement, this.name, this.unit, this.loss);
  double get qty => -movement.qty;
}

class WastageRepository {
  WastageRepository._();
  static final WastageRepository instance = WastageRepository._();

  Future<List<Product>> products() => StockAdjustmentRepository.instance.loadProducts();

  /// Wastage likho ([qty] product ki SMALLEST unit mein).
  Future<void> add(String barcode, double qty, String reason, {String note = ''}) =>
      StockAdjustmentRepository.instance.save(barcode, AdjustmentKind.damage, qty,
          note: note.trim().isEmpty ? 'Wastage: $reason' : 'Wastage: $reason — ${note.trim()}');

  /// [from]..[to] ki saari DAMAGE rows, naya pehle, nuqsan (Rs) samet.
  Future<List<WastageRow>> between(DateTime from, DateTime to) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('stock_movements',
        where: 'type=? AND createdAt >= ? AND createdAt < ?',
        whereArgs: [MovementType.damage, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        orderBy: 'createdAt DESC, id DESC');
    final moves = rows.map(StockMovement.fromMap).toList();
    if (moves.isEmpty) return const [];
    final codes = moves.map((m) => m.barcode).toSet().toList();
    final prows = await db.query('products',
        where: 'barcode IN (${List.filled(codes.length, '?').join(',')})', whereArgs: codes);
    final byCode = {for (final m in prows) m['barcode'] as String: Product.fromMap(m)};
    return moves.map((m) {
      final p = byCode[m.barcode];
      final factor = p?.smallestUnitFactor() ?? 1.0;
      final loss = (-m.qty) * costPerSmallestOf(m.cost, factor);
      return WastageRow(m, p?.name ?? m.barcode, p?.smallestUnitName() ?? m.unit, loss);
    }).toList();
  }
}
