import 'package:sqflite/sqflite.dart';

import '../models/bakery_order.dart';
import '../models/misc_entities.dart';
import '../services/session.dart';
import '../sync/sync_queue_helper.dart';
import 'app_database.dart';
import 'cash_repository.dart' show incomeReasonPrefix;
import 'expense_repository.dart';

export '../models/bakery_order.dart';

class BakeryOrderException implements Exception {
  final String message;
  const BakeryOrderException(this.message);
  @override
  String toString() => message;
}

/// Cake / custom orders (table `bakery_orders`).
///
/// Paisa: advance aur delivery wali payment dono `cash_transactions` mein Cash IN row likhte hain
/// (reason `Income: Cake Order ...`, reference `manual-order-...`), is liye Day Book, Cash & Bank aur
/// Reports (Other Income) mein khud aa jate hain aur cloud sync se doosre devices par bhi jate hain.
/// Cancel par advance wapas karein to wo Expense (Miscellaneous) ban kar profit se minus hota hai.
class BakeryOrderRepository {
  BakeryOrderRepository._();
  static final BakeryOrderRepository instance = BakeryOrderRepository._();

  static const _table = 'bakery_orders';

  Future<Database> get _db => AppDatabase.instance.database;

  Future<BakeryOrder?> byId(int id) async {
    final rows = await (await _db).query(_table, where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : BakeryOrder.fromMap(rows.first);
  }

  /// Khule orders (pending + ready), jo pehle dena hai wo upar.
  Future<List<BakeryOrder>> open() async {
    final rows = await (await _db).query(_table,
        where: 'status IN (?, ?)',
        whereArgs: [BakeryOrderStatus.pending, BakeryOrderStatus.ready],
        orderBy: 'deliveryAt ASC, id ASC');
    return rows.map(BakeryOrder.fromMap).toList();
  }

  /// Band orders (delivered + cancelled), naye pehle.
  Future<List<BakeryOrder>> closed({int limit = 200}) async {
    final rows = await (await _db).query(_table,
        where: 'status IN (?, ?)',
        whereArgs: [BakeryOrderStatus.delivered, BakeryOrderStatus.cancelled],
        orderBy: 'closedAt DESC, id DESC',
        limit: limit);
    return rows.map(BakeryOrder.fromMap).toList();
  }

  /// Ek din ke orders (delivery date se), har status.
  Future<List<BakeryOrder>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;
    final rows = await (await _db).query(_table,
        where: 'deliveryAt >= ? AND deliveryAt < ?', whereArgs: [start, end], orderBy: 'deliveryAt ASC, id ASC');
    return rows.map(BakeryOrder.fromMap).toList();
  }

  Future<BakeryOrderCounts> counts({DateTime? now}) async => countOrders(await open(), now ?? DateTime.now());

  /// Naya order. [advanceMethod] = 'cash' | 'bank'. Wapas: naye order ki id.
  Future<int> create(BakeryOrder o, {String advanceMethod = 'cash'}) async {
    final err = validateOrder(customerName: o.customerName, item: o.item, total: o.total, advance: o.advance);
    if (err != null) throw BakeryOrderException(err);
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    return db.transaction((txn) async {
      final map = BakeryOrder(
        customerName: o.customerName.trim(),
        phone: o.phone.trim(),
        item: o.item.trim(),
        flavour: o.flavour.trim(),
        weight: o.weight,
        weightUnit: o.weightUnit,
        cakeMessage: o.cakeMessage.trim(),
        notes: o.notes.trim(),
        homeDelivery: o.homeDelivery,
        address: o.address.trim(),
        total: o.total,
        advance: o.advance,
        deliveryAt: o.deliveryAt,
        createdBy: Session.username ?? '',
        createdAt: now,
        updatedAt: now,
      ).toMap();
      final id = await txn.insert(_table, map);
      if (o.advance > 0) {
        await _cashIn(txn, id, o.advance, advanceMethod, 'advance', o.customerName.trim(), now);
      }
      return id;
    });
  }

  /// Order ki tafseel badlo (paisa nahi — advance/payment ke liye [receive]).
  /// Total kam karke wusool shuda se neeche nahi la sakte.
  Future<void> update(BakeryOrder o) async {
    final id = o.id;
    if (id == null) throw const BakeryOrderException('Order nahi mila');
    final old = await byId(id);
    if (old == null) throw const BakeryOrderException('Order nahi mila');
    if (!old.isOpen) throw const BakeryOrderException('Band order badla nahi ja sakta');
    final err = validateOrder(customerName: o.customerName, item: o.item, total: o.total, advance: old.advance);
    if (err != null) throw BakeryOrderException(err);
    if (o.total + 0.004 < old.received) {
      throw BakeryOrderException('Total wusool shuda raqam (Rs ${old.received.round()}) se kam nahi ho sakta');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = old.copyWith(
      customerName: o.customerName.trim(),
      phone: o.phone.trim(),
      item: o.item.trim(),
      flavour: o.flavour.trim(),
      weight: o.weight,
      weightUnit: o.weightUnit,
      cakeMessage: o.cakeMessage.trim(),
      notes: o.notes.trim(),
      homeDelivery: o.homeDelivery,
      address: o.address.trim(),
      total: o.total,
      deliveryAt: o.deliveryAt,
      updatedAt: now,
    );
    await (await _db).update(_table, updated.toMap(), where: 'id=?', whereArgs: [id]);
  }

  /// Tayyar / wapas pending.
  Future<void> setReady(int id, bool ready) async {
    final o = await byId(id);
    if (o == null || !o.isOpen) throw const BakeryOrderException('Order khula nahi');
    await (await _db).update(
        _table,
        {
          'status': ready ? BakeryOrderStatus.ready : BakeryOrderStatus.pending,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id=?',
        whereArgs: [id]);
  }

  /// Payment lo (baqi mein se). [deliver] = saath hi order delivered.
  Future<void> receive(int id, double amount, {String method = 'cash', bool deliver = false}) async {
    if (!amount.isFinite || amount < 0) throw const BakeryOrderException('Sahi raqam likhen');
    if (method != 'cash' && method != 'bank') throw const BakeryOrderException('Method cash ya bank');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw const BakeryOrderException('Order nahi mila');
      final o = BakeryOrder.fromMap(rows.first);
      if (!o.isOpen) throw const BakeryOrderException('Order pehle hi band hai');
      if (amount > o.balance + 0.004) {
        throw BakeryOrderException('Baqi sirf Rs ${o.balance.round()} hai');
      }
      if (amount == 0 && !deliver) throw const BakeryOrderException('Raqam likhen');
      final now = DateTime.now().millisecondsSinceEpoch;
      final values = <String, Object?>{'paid': o.paid + amount, 'updatedAt': now};
      if (deliver) {
        values['status'] = BakeryOrderStatus.delivered;
        values['closedAt'] = now;
      }
      await txn.update(_table, values, where: 'id=?', whereArgs: [id]);
      if (amount > 0) {
        await _cashIn(txn, id, amount, method, deliver ? 'delivery' : 'payment', o.customerName, now);
      }
    });
  }

  /// Order cancel. [refund] = customer ko kitna wapas diya (0..wusool shuda) — Expense ban kar likha jata hai.
  Future<void> cancel(int id, {double refund = 0, String method = 'cash'}) async {
    if (!refund.isFinite || refund < 0) throw const BakeryOrderException('Sahi raqam likhen');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw const BakeryOrderException('Order nahi mila');
      final o = BakeryOrder.fromMap(rows.first);
      if (!o.isOpen) throw const BakeryOrderException('Order pehle hi band hai');
      if (refund > o.received + 0.004) {
        throw BakeryOrderException('Wapsi wusool shuda (Rs ${o.received.round()}) se zyada nahi');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(_table, {'status': BakeryOrderStatus.cancelled, 'closedAt': now, 'updatedAt': now},
          where: 'id=?', whereArgs: [id]);
      if (refund > 0) {
        await ExpenseRepository.insertExpenseWithCash(
          txn,
          category: ExpenseCategories.miscellaneous,
          description: 'Cake order ${o.number} cancel — advance wapas (${o.customerName})',
          amount: refund,
          method: method,
          now: now,
        );
      }
    });
  }

  /// Ghalti se bana order (koi paisa nahi liya) mita do. Paisa liya ho to [cancel] karein.
  Future<void> deleteUnpaid(int id) async {
    final o = await byId(id);
    if (o == null) return;
    if (o.received > 0) throw const BakeryOrderException('Is order par paisa liya ja chuka — Cancel karein');
    await (await _db).delete(_table, where: 'id=?', whereArgs: [id]);
  }

  /// Ek muddat ka khulasa (delivery date se): orders, kul qeemat, wusool, cancel.
  Future<({int orders, int delivered, int cancelled, double value, double received})> summary(
      DateTime from, DateTime to) async {
    final rows = await (await _db).rawQuery(
      'SELECT status, COUNT(*) AS n, COALESCE(SUM(total),0) AS t, COALESCE(SUM(advance+paid),0) AS r '
      'FROM $_table WHERE deliveryAt >= ? AND deliveryAt < ? GROUP BY status',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    var orders = 0, delivered = 0, cancelled = 0;
    var value = 0.0, received = 0.0;
    for (final r in rows) {
      final n = (r['n'] as num).toInt();
      final st = r['status'] as String;
      orders += n;
      if (st == BakeryOrderStatus.delivered) delivered += n;
      if (st == BakeryOrderStatus.cancelled) {
        cancelled += n;
      } else {
        value += (r['t'] as num).toDouble();
      }
      received += (r['r'] as num).toDouble();
    }
    return (orders: orders, delivered: delivered, cancelled: cancelled, value: value, received: received);
  }

  Future<void> _cashIn(
      Transaction txn, int orderId, double amount, String method, String kind, String customer, int now) async {
    final number = '#${orderId.toString().padLeft(5, '0')}';
    final cash = CashTransaction(
      type: 'IN',
      method: method,
      amount: amount,
      // `Income: ` = Reports / Balance Sheet isay Other Income mein jorte hain.
      reason: '${incomeReasonPrefix}Cake Order $number $kind — $customer',
      // `manual-` = Day Book isay alag line mein dikhata hai.
      reference: 'manual-order-$orderId-$kind-$now',
      createdAt: now,
      updatedAt: now,
    );
    final cashId = await txn.insert('cash_transactions', cash.toMap());
    await SyncQueueHelper.enqueueLegacy(txn, 'cash_transaction', '$cashId', 'create', {...cash.toMap(), 'id': cashId});
  }
}
