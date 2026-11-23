/// Bakery: cake / custom order (booking). Table `bakery_orders` (DB v39).
///
/// Paisa: [total] = order ki kul qeemat, [advance] = booking par mila, [paid] = baad mein (delivery par) mila.
/// Baqi = total - advance - paid. Har payment ki cash row (`cash_transactions`, reason `Income: ...`) bhi banti
/// hai taake Day Book / Cash / Reports (Other Income) mein nazar aaye.
class BakeryOrderStatus {
  BakeryOrderStatus._();
  static const pending = 'pending'; // booking ho gayi, abhi tayyar nahi
  static const ready = 'ready'; // tayyar — customer ka intezar
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const all = <String>[pending, ready, delivered, cancelled];

  static bool isOpen(String s) => s == pending || s == ready;
}

class BakeryOrder {
  final int? id;
  final String customerName;
  final String phone;

  /// Kya banana hai — e.g. "Chocolate fudge cake", "50 cup cakes".
  final String item;
  final String flavour;

  /// Cake ka wazan (pound / kg — [weightUnit]); 0 = lagu nahi.
  final double weight;
  final String weightUnit;

  /// Cake par likhwana (e.g. "Happy Birthday Ali").
  final String cakeMessage;

  /// Design / colour / tiers / photo ka hawala wagaira.
  final String notes;

  /// true = ghar par delivery, false = dukaan se pickup.
  final bool homeDelivery;
  final String address;

  final double total;
  final double advance;
  final double paid;

  /// Kab deni hai (millis, date + waqt).
  final int deliveryAt;
  final String status;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final int closedAt; // delivered / cancelled ka waqt (0 = khula)

  const BakeryOrder({
    this.id,
    required this.customerName,
    this.phone = '',
    required this.item,
    this.flavour = '',
    this.weight = 0,
    this.weightUnit = 'lb',
    this.cakeMessage = '',
    this.notes = '',
    this.homeDelivery = false,
    this.address = '',
    required this.total,
    this.advance = 0,
    this.paid = 0,
    required this.deliveryAt,
    this.status = BakeryOrderStatus.pending,
    this.createdBy = '',
    required this.createdAt,
    this.updatedAt = 0,
    this.closedAt = 0,
  });

  double get received => advance + paid;
  double get balance {
    final b = total - received;
    return b > 0.004 ? b : 0;
  }

  bool get isOpen => BakeryOrderStatus.isOpen(status);

  /// Order number (dikhane ke liye): #00012
  String get number => id == null ? '#new' : '#${id.toString().padLeft(5, '0')}';

  DateTime get deliveryTime => DateTime.fromMillisecondsSinceEpoch(deliveryAt);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'customerName': customerName,
        'phone': phone,
        'item': item,
        'flavour': flavour,
        'weight': weight,
        'weightUnit': weightUnit,
        'cakeMessage': cakeMessage,
        'notes': notes,
        'homeDelivery': homeDelivery ? 1 : 0,
        'address': address,
        'total': total,
        'advance': advance,
        'paid': paid,
        'deliveryAt': deliveryAt,
        'status': status,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'closedAt': closedAt,
      };

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  static String _s(Object? v) => (v as String?) ?? '';

  factory BakeryOrder.fromMap(Map<String, Object?> m) => BakeryOrder(
        id: m['id'] as int?,
        customerName: _s(m['customerName']),
        phone: _s(m['phone']),
        item: _s(m['item']),
        flavour: _s(m['flavour']),
        weight: _d(m['weight']),
        weightUnit: m['weightUnit'] == null ? 'lb' : _s(m['weightUnit']),
        cakeMessage: _s(m['cakeMessage']),
        notes: _s(m['notes']),
        homeDelivery: _i(m['homeDelivery']) != 0,
        address: _s(m['address']),
        total: _d(m['total']),
        advance: _d(m['advance']),
        paid: _d(m['paid']),
        deliveryAt: _i(m['deliveryAt']),
        status: m['status'] == null ? BakeryOrderStatus.pending : _s(m['status']),
        createdBy: _s(m['createdBy']),
        createdAt: _i(m['createdAt']),
        updatedAt: _i(m['updatedAt']),
        closedAt: _i(m['closedAt']),
      );

  BakeryOrder copyWith({
    String? customerName,
    String? phone,
    String? item,
    String? flavour,
    double? weight,
    String? weightUnit,
    String? cakeMessage,
    String? notes,
    bool? homeDelivery,
    String? address,
    double? total,
    double? advance,
    double? paid,
    int? deliveryAt,
    String? status,
    int? updatedAt,
    int? closedAt,
  }) =>
      BakeryOrder(
        id: id,
        customerName: customerName ?? this.customerName,
        phone: phone ?? this.phone,
        item: item ?? this.item,
        flavour: flavour ?? this.flavour,
        weight: weight ?? this.weight,
        weightUnit: weightUnit ?? this.weightUnit,
        cakeMessage: cakeMessage ?? this.cakeMessage,
        notes: notes ?? this.notes,
        homeDelivery: homeDelivery ?? this.homeDelivery,
        address: address ?? this.address,
        total: total ?? this.total,
        advance: advance ?? this.advance,
        paid: paid ?? this.paid,
        deliveryAt: deliveryAt ?? this.deliveryAt,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        closedAt: closedAt ?? this.closedAt,
      );
}

/// Dashboard / notification ke liye ginti.
class BakeryOrderCounts {
  final int late; // delivery ka waqt guzar gaya, abhi khula
  final int dueToday;
  final int dueTomorrow;
  final int ready;
  final int open;
  final double balanceDue; // khule orders par baqi raqam
  const BakeryOrderCounts({
    this.late = 0,
    this.dueToday = 0,
    this.dueTomorrow = 0,
    this.ready = 0,
    this.open = 0,
    this.balanceDue = 0,
  });

  int get total => late + dueToday + dueTomorrow;
}

/// Pure (test ke liye): khule orders ki ginti [now] ke hisaab se.
BakeryOrderCounts countOrders(Iterable<BakeryOrder> orders, DateTime now) {
  final startToday = DateTime(now.year, now.month, now.day);
  final startTomorrow = startToday.add(const Duration(days: 1));
  final startDayAfter = startToday.add(const Duration(days: 2));
  var late = 0, today = 0, tomorrow = 0, ready = 0, open = 0;
  var bal = 0.0;
  for (final o in orders) {
    if (!o.isOpen) continue;
    open++;
    bal += o.balance;
    if (o.status == BakeryOrderStatus.ready) ready++;
    final t = o.deliveryTime;
    if (t.isBefore(now) && t.isBefore(startTomorrow) && !t.isBefore(startToday)) {
      // aaj ka, waqt guzar gaya — late bhi aur aaj bhi; sirf late ginein
      late++;
    } else if (t.isBefore(startToday)) {
      late++;
    } else if (t.isBefore(startTomorrow)) {
      today++;
    } else if (t.isBefore(startDayAfter)) {
      tomorrow++;
    }
  }
  return BakeryOrderCounts(
      late: late, dueToday: today, dueTomorrow: tomorrow, ready: ready, open: open, balanceDue: bal);
}

/// Validation (pure). null = theek.
String? validateOrder({
  required String customerName,
  required String item,
  required double? total,
  required double? advance,
}) {
  if (customerName.trim().isEmpty) return 'Customer ka naam likhen';
  if (item.trim().isEmpty) return 'Kya banana hai (item) likhen';
  if (total == null || !total.isFinite || total < 0) return 'Sahi total raqam likhen';
  if (advance == null || !advance.isFinite || advance < 0) return 'Sahi advance likhen';
  if (advance > total + 0.004) return 'Advance total se zyada nahi ho sakta';
  return null;
}

/// Customer slip / WhatsApp ka matn (plain ASCII-friendly).
String orderSlipText(BakeryOrder o, {String shopName = '', String shopPhone = ''}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final t = o.deliveryTime;
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final when = '${two(t.day)}-${two(t.month)}-${t.year}  $h:${two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
  final b = StringBuffer();
  if (shopName.isNotEmpty) b.writeln(shopName.toUpperCase());
  if (shopPhone.isNotEmpty) b.writeln('Ph: $shopPhone');
  b.writeln('--------------------------------');
  b.writeln('ORDER ${o.number}');
  b.writeln('Customer: ${o.customerName}');
  if (o.phone.isNotEmpty) b.writeln('Phone: ${o.phone}');
  b.writeln('Item: ${o.item}');
  if (o.flavour.isNotEmpty) b.writeln('Flavour: ${o.flavour}');
  if (o.weight > 0) b.writeln('Weight: ${_num(o.weight)} ${o.weightUnit}');
  if (o.cakeMessage.isNotEmpty) b.writeln('Message: ${o.cakeMessage}');
  if (o.notes.isNotEmpty) b.writeln('Notes: ${o.notes}');
  b.writeln('${o.homeDelivery ? 'Delivery' : 'Pickup'}: $when');
  if (o.homeDelivery && o.address.isNotEmpty) b.writeln('Address: ${o.address}');
  b.writeln('--------------------------------');
  b.writeln('Total:    Rs ${_num(o.total)}');
  b.writeln('Advance:  Rs ${_num(o.advance)}');
  if (o.paid > 0) b.writeln('Paid:     Rs ${_num(o.paid)}');
  b.writeln('Balance:  Rs ${_num(o.balance)}');
  b.writeln('--------------------------------');
  b.writeln('Slip sambhal kar rakhein. Shukriya!');
  return b.toString();
}

String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
