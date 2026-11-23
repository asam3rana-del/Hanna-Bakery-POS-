import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Database;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ah_developer_kiryana_store/db/app_database.dart';
import 'package:ah_developer_kiryana_store/db/bakery_order_repository.dart';
import 'package:ah_developer_kiryana_store/db/production_repository.dart';
import 'package:ah_developer_kiryana_store/db/wastage_repository.dart';
import 'package:ah_developer_kiryana_store/models/product.dart';
import 'package:ah_developer_kiryana_store/services/due_alert_service.dart';
import 'package:ah_developer_kiryana_store/services/session.dart';

BakeryOrder _order({
  int? id,
  String status = BakeryOrderStatus.pending,
  required DateTime at,
  double total = 3000,
  double advance = 1000,
  double paid = 0,
}) =>
    BakeryOrder(
      id: id,
      customerName: 'Ali',
      item: 'Birthday cake',
      total: total,
      advance: advance,
      paid: paid,
      deliveryAt: at.millisecondsSinceEpoch,
      status: status,
      createdAt: 0,
    );

void main() {
  group('pure', () {
    final now = DateTime(2026, 11, 23, 12, 0);

    test('countOrders: late / today / tomorrow / ready / balance', () {
      final c = countOrders([
        _order(at: DateTime(2026, 11, 22, 17)), // late (kal tha)
        _order(at: DateTime(2026, 11, 23, 10)), // late (aaj subah)
        _order(at: DateTime(2026, 11, 23, 18), status: BakeryOrderStatus.ready), // aaj
        _order(at: DateTime(2026, 11, 24, 9)), // kal
        _order(at: DateTime(2026, 11, 30, 9)), // baad mein
        _order(at: DateTime(2026, 11, 23, 18), status: BakeryOrderStatus.delivered), // band — ginti mein nahi
      ], now);
      expect(c.late, 2);
      expect(c.dueToday, 1);
      expect(c.dueTomorrow, 1);
      expect(c.ready, 1);
      expect(c.open, 5);
      expect(c.balanceDue, 5 * 2000);
      expect(c.total, 4);
    });

    test('balance never negative; number format', () {
      final o = _order(id: 12, at: now, total: 1000, advance: 600, paid: 400);
      expect(o.balance, 0);
      expect(o.number, '#00012');
    });

    test('validateOrder', () {
      expect(validateOrder(customerName: '', item: 'x', total: 1, advance: 0), isNotNull);
      expect(validateOrder(customerName: 'a', item: '', total: 1, advance: 0), isNotNull);
      expect(validateOrder(customerName: 'a', item: 'x', total: 100, advance: 200), isNotNull);
      expect(validateOrder(customerName: 'a', item: 'x', total: null, advance: 0), isNotNull);
      expect(validateOrder(customerName: 'a', item: 'x', total: 100, advance: 100), isNull);
    });

    test('toMap / fromMap round trip', () {
      final o = BakeryOrder(
        id: 3,
        customerName: 'Sara',
        phone: '0300',
        item: 'Wedding cake',
        flavour: 'Vanilla',
        weight: 4.5,
        weightUnit: 'kg',
        cakeMessage: 'Congrats',
        notes: '2 tier',
        homeDelivery: true,
        address: 'Bhikhi',
        total: 9000,
        advance: 4000,
        paid: 1000,
        deliveryAt: now.millisecondsSinceEpoch,
        status: BakeryOrderStatus.ready,
        createdBy: 'admin',
        createdAt: 5,
        updatedAt: 6,
        closedAt: 0,
      );
      final b = BakeryOrder.fromMap(o.toMap());
      expect(b.toMap(), o.toMap());
      expect(b.balance, 4000);
    });

    test('slip text has the money lines', () {
      final t = orderSlipText(_order(id: 1, at: now), shopName: 'Hanna Bakers');
      expect(t, contains('HANNA BAKERS'));
      expect(t, contains('ORDER #00001'));
      expect(t, contains('Balance:  Rs 2000'));
    });

    test('order notification body', () {
      final body = DueAlertService.bodyFor(const BakeryOrderCounts(late: 1, dueToday: 2, balanceDue: 1500));
      expect(body, contains('1 order late'));
      expect(body, contains('aaj 2'));
      expect(body, contains('Rs 1500'));
    });

    test('planProduction: needs, shortages, cost per smallest unit', () {
      const maida = Product(barcode: 'maida', name: 'Maida', unit: 'kg', cost: 120, stock: 3);
      const sugar = Product(barcode: 'sugar', name: 'Sugar', unit: 'kg', cost: 150, stock: 10);
      const bread = Product(barcode: 'bread', name: 'Bread', unit: 'pcs', cost: 0, stock: 0);
      const r = Recipe(barcode: 'bread', yieldQty: 20, items: [RecipeItem('maida', 2), RecipeItem('sugar', 0.5)]);
      final plan = planProduction(r, 2, {'maida': maida, 'sugar': sugar, 'bread': bread});
      expect(plan.produce, 40);
      expect(plan.needs.firstWhere((n) => n.barcode == 'maida').need, 4);
      expect(plan.anyShort, isTrue); // 4 kg maida chahiye, 3 hai
      expect(plan.shortages.single.barcode, 'maida');
      expect(plan.materialCost, closeTo(4 * 120 + 1 * 150, 1e-9));
    });
  });

  group('database', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late Directory tempDir;
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('bakery_test_');
      await AppDatabase.instance.close();
      await databaseFactory.setDatabasesPath(tempDir.path);
      db = await AppDatabase.instance.database;
      Session.username = 'bakery-admin';
      Session.role = 'admin';
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      Session.username = null;
      Session.role = 'cashier';
      await tempDir.delete(recursive: true);
    });

    Future<double> cashIn() async =>
        ((await db.rawQuery("SELECT COALESCE(SUM(amount),0) AS t FROM cash_transactions WHERE type='IN'")).first['t'] as num)
            .toDouble();

    test('order: advance -> payment -> deliver writes income cash rows', () async {
      final repo = BakeryOrderRepository.instance;
      final id = await repo.create(_order(at: DateTime.now().add(const Duration(days: 1))));
      expect(await cashIn(), 1000);
      var o = (await repo.byId(id))!;
      expect(o.balance, 2000);
      expect((await repo.open()).length, 1);

      await repo.receive(id, 500);
      await repo.receive(id, 1500, deliver: true);
      o = (await repo.byId(id))!;
      expect(o.status, BakeryOrderStatus.delivered);
      expect(o.balance, 0);
      expect(await cashIn(), 3000);
      expect((await repo.open()), isEmpty);
      final reasons = (await db.query('cash_transactions')).map((r) => r['reason'] as String);
      expect(reasons.every((r) => r.startsWith('Income: Cake Order')), isTrue);
      await expectLater(repo.receive(id, 1), throwsA(isA<BakeryOrderException>()));
    });

    test('order: cannot over-collect; cancel with refund books an expense', () async {
      final repo = BakeryOrderRepository.instance;
      final id = await repo.create(_order(at: DateTime.now()));
      await expectLater(repo.receive(id, 5000), throwsA(isA<BakeryOrderException>()));
      await repo.cancel(id, refund: 1000);
      final o = (await repo.byId(id))!;
      expect(o.status, BakeryOrderStatus.cancelled);
      final exp = await db.query('expenses');
      expect(exp.single['amount'], 1000);
      await expectLater(repo.deleteUnpaid(id), throwsA(isA<BakeryOrderException>()));
    });

    test('production moves stock both ways and logs it', () async {
      for (final p in const [
        Product(barcode: 'maida', name: 'Maida', unit: 'kg', cost: 120, stock: 10),
        Product(barcode: 'egg', name: 'Egg', unit: 'pcs', cost: 25, stock: 30),
        Product(barcode: 'cake', name: 'Plain Cake', unit: 'pcs', cost: 0, stock: 1),
      ]) {
        await db.insert('products', p.toMap());
      }
      final repo = ProductionRepository.instance;
      await repo.saveRecipe(const Recipe(barcode: 'cake', yieldQty: 4, items: [RecipeItem('maida', 1), RecipeItem('egg', 6)]));
      final r = (await repo.recipes()).single;
      expect(r.items.length, 2);

      await repo.produce(r, 2);
      Future<double> stock(String b) async =>
          ((await db.query('products', where: 'barcode=?', whereArgs: [b])).first['stock'] as num).toDouble();
      expect(await stock('cake'), 9);
      expect(await stock('maida'), 8);
      expect(await stock('egg'), 18);
      final log = await db.query('production_log');
      expect(log.single['producedQty'], 8);
      expect(((log.single['materialCost']) as num).toDouble(), closeTo(2 * 120 + 12 * 25, 1e-9));

      // 6 batch = 36 anday chahiye, 18 hain -> rok do (jab tak allowShort na ho)
      await expectLater(repo.produce(r, 6), throwsA(isA<ProductionException>()));
      expect(await stock('egg'), 18);

      // Recipe dobara save = update (duplicate nahi)
      await repo.saveRecipe(const Recipe(barcode: 'cake', yieldQty: 5, items: [RecipeItem('maida', 1)]));
      final again = await repo.recipes();
      expect(again.length, 1);
      expect(again.single.yieldQty, 5);
      expect(again.single.items.length, 1);
    });

    test('wastage reduces stock and reports loss at cost', () async {
      await db.insert('products', const Product(barcode: 'bun', name: 'Bun', unit: 'pcs', cost: 20, stock: 50).toMap());
      await WastageRepository.instance.add('bun', 5, WastageReasons.all.first);
      final now = DateTime.now();
      final rows = await WastageRepository.instance
          .between(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
      expect(rows.single.qty, 5);
      expect(rows.single.loss, closeTo(100, 1e-9));
      final stock = (await db.query('products', where: "barcode='bun'")).first['stock'] as num;
      expect(stock, 45);
    });
  });
}
