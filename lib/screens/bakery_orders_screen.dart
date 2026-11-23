import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/bakery_order_repository.dart';
import '../db/user_repository.dart';
import '../services/printer_service.dart';
import '../services/session.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';

/// Bakery: cake / custom orders — booking (advance), tayyari, delivery (baqi wusooli), cancel (advance wapsi).
///
/// Tab 1 "Open": jo dene hain — late, aaj, kal, baad mein (delivery waqt ki tarteeb).
/// Tab 2 "Done": delivered + cancelled.
/// Har order par: Ready, Payment, Deliver, Edit, Print slip, WhatsApp, Call, Cancel.
class BakeryOrdersScreen extends StatefulWidget {
  const BakeryOrdersScreen({super.key});

  @override
  State<BakeryOrdersScreen> createState() => _BakeryOrdersScreenState();
}

final _dayFmt = DateFormat('EEE d MMM');
final _timeFmt = DateFormat('h:mm a');

String _rs(double v) => 'Rs ${NumberFormat('#,##0').format(v.round())}';

class _BakeryOrdersScreenState extends State<BakeryOrdersScreen> {
  final _repo = BakeryOrderRepository.instance;
  List<BakeryOrder> _open = const [];
  List<BakeryOrder> _closed = const [];
  bool _loading = true;
  String _query = '';

  AppPalette get _p => ThemeManager.palette;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _repo.open();
      final c = await _repo.closed();
      if (!mounted) return;
      setState(() {
        _open = o;
        _closed = c;
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

  bool _match(BakeryOrder o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.customerName.toLowerCase().contains(q) ||
        o.phone.contains(q) ||
        o.item.toLowerCase().contains(q) ||
        o.number.contains(q);
  }

  Future<void> _newOrder() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const BakeryOrderFormScreen()));
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final counts = countOrders(_open, DateTime.now());
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.navy,
          foregroundColor: Colors.white,
          title: Text(Loc.t('Cake Orders', 'کیک آرڈرز')),
          actions: [
            IconButton(
              tooltip: Loc.t('Order summary', 'آرڈرز کا خلاصہ'),
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BakeryOrderSummaryScreen())),
            ),
            IconButton(tooltip: Loc.t('Refresh', 'ریفریش'), icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: ThemeManager.gold,
            tabs: [
              Tab(text: '${Loc.t('Open', 'کھلے')} (${_open.length})'),
              Tab(text: Loc.t('Done', 'مکمل')),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newOrder,
          icon: const Icon(Icons.add),
          label: Text(Loc.t('New Order', 'نیا آرڈر')),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: Loc.t('Search name, phone, item, #no', 'نام، فون، آئٹم، نمبر تلاش کریں'),
                filled: true,
                fillColor: p.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_open.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                if (counts.late > 0) _chip('${counts.late} ${Loc.t('late', 'لیٹ')}', p.red),
                _chip('${counts.dueToday} ${Loc.t('today', 'آج')}', p.flatPinkFg),
                _chip('${counts.dueTomorrow} ${Loc.t('tomorrow', 'کل')}', p.flatBlueFg),
                _chip('${counts.ready} ${Loc.t('ready', 'تیار')}', p.flatTealFg),
                if (counts.balanceDue > 0) _chip('${Loc.t('To collect', 'وصولی')} ${_rs(counts.balanceDue)}', p.flatAmberFg),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _list(_open.where(_match).toList(), grouped: true),
                    _list(_closed.where(_match).toList(), grouped: false),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      );

  String _groupOf(BakeryOrder o, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final t = o.deliveryTime;
    if (t.isBefore(now)) return Loc.t('LATE', 'لیٹ');
    if (t.isBefore(today.add(const Duration(days: 1)))) return Loc.t('TODAY', 'آج');
    if (t.isBefore(today.add(const Duration(days: 2)))) return Loc.t('TOMORROW', 'کل');
    return Loc.t('LATER', 'بعد میں');
  }

  Widget _list(List<BakeryOrder> orders, {required bool grouped}) {
    final p = _p;
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 80),
          Icon(Icons.cake_outlined, size: 56, color: p.textMuted),
          const SizedBox(height: 10),
          Center(
            child: Text(
              grouped ? Loc.t('No open orders', 'کوئی کھلا آرڈر نہیں') : Loc.t('Nothing here yet', 'ابھی کچھ نہیں'),
              style: TextStyle(color: p.textMuted),
            ),
          ),
        ]),
      );
    }
    final now = DateTime.now();
    final children = <Widget>[];
    String? last;
    for (final o in orders) {
      if (grouped) {
        final g = _groupOf(o, now);
        if (g != last) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Text(g,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
          ));
          last = g;
        }
      }
      children.add(_card(o, now));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: children),
    );
  }

  (String, Color) _status(BakeryOrder o, DateTime now) {
    final p = _p;
    switch (o.status) {
      case BakeryOrderStatus.ready:
        return (Loc.t('READY', 'تیار'), p.flatTealFg);
      case BakeryOrderStatus.delivered:
        return (Loc.t('DELIVERED', 'ڈیلیور'), p.flatBlueFg);
      case BakeryOrderStatus.cancelled:
        return (Loc.t('CANCELLED', 'منسوخ'), p.textMuted);
      default:
        return o.deliveryTime.isBefore(now) ? (Loc.t('LATE', 'لیٹ'), p.red) : (Loc.t('PENDING', 'باقی'), p.flatAmberFg);
    }
  }

  Widget _card(BakeryOrder o, DateTime now) {
    final p = _p;
    final (label, color) = _status(o, now);
    final t = o.deliveryTime;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openActions(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.textMuted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(o.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: p.textDark)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            [
              o.item,
              if (o.weight > 0) '${_n(o.weight)} ${o.weightUnit}',
              if (o.flavour.isNotEmpty) o.flavour,
            ].join('  •  '),
            style: TextStyle(fontSize: 13.5, color: p.textDark),
          ),
          if (o.cakeMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('“${o.cakeMessage}”', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: p.textMuted)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(o.homeDelivery ? Icons.delivery_dining_outlined : Icons.storefront_outlined, size: 16, color: p.textMuted),
            const SizedBox(width: 4),
            Text('${_dayFmt.format(t)}, ${_timeFmt.format(t)}', style: TextStyle(fontSize: 12.5, color: p.textMuted)),
            const Spacer(),
            if (o.balance > 0 && o.status != BakeryOrderStatus.cancelled)
              Text('${Loc.t('Balance', 'باقی')} ${_rs(o.balance)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: p.red))
            else
              Text(_rs(o.total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: p.textDark)),
          ]),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> _openActions(BakeryOrder o) async {
    final p = _p;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        Widget tile(String id, IconData icon, String text, {Color? color}) => ListTile(
              leading: Icon(icon, color: color ?? p.teal),
              title: Text(text, style: TextStyle(color: color ?? p.textDark)),
              onTap: () => Navigator.of(ctx).pop(id),
            );
        return SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('${o.number}  ${o.customerName}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: p.textDark)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '${Loc.t('Total', 'کل')} ${_rs(o.total)}   •   ${Loc.t('Received', 'وصول')} ${_rs(o.received)}   •   '
                '${Loc.t('Balance', 'باقی')} ${_rs(o.balance)}',
                style: TextStyle(color: p.textMuted, fontSize: 13),
              ),
            ),
            const Divider(height: 1),
            if (o.isOpen && o.status == BakeryOrderStatus.pending)
              tile('ready', Icons.check_circle_outline, Loc.t('Mark READY', 'تیار ہو گیا')),
            if (o.isOpen && o.status == BakeryOrderStatus.ready)
              tile('unready', Icons.undo, Loc.t('Back to pending', 'واپس باقی میں')),
            if (o.isOpen)
              tile('deliver', Icons.local_shipping_outlined, Loc.t('Deliver & collect balance', 'ڈیلیور کریں اور باقی وصول کریں'),
                  color: p.flatTealFg),
            if (o.isOpen && o.balance > 0) tile('pay', Icons.payments_outlined, Loc.t('Receive payment', 'رقم وصول کریں')),
            if (o.isOpen) tile('edit', Icons.edit_outlined, Loc.t('Edit order', 'آرڈر میں تبدیلی')),
            tile('print', Icons.print_outlined, Loc.t('Print slip', 'پرچی پرنٹ کریں')),
            tile('share', Icons.share_outlined, Loc.t('Share slip (WhatsApp)', 'پرچی شیئر کریں (واٹس ایپ)')),
            if (o.phone.isNotEmpty) tile('call', Icons.phone_outlined, Loc.t('Call customer', 'کسٹمر کو کال کریں')),
            if (o.isOpen && Session.isAdminOrManager)
              tile('cancel', Icons.cancel_outlined, Loc.t('Cancel order', 'آرڈر منسوخ کریں'), color: p.red),
            if (o.received <= 0 && Session.isAdminOrManager)
              tile('delete', Icons.delete_outline, Loc.t('Delete (mistake)', 'حذف کریں (غلطی)'), color: p.red),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
    if (action == null || !mounted) return;
    final id = o.id!;
    try {
      switch (action) {
        case 'ready':
          await _repo.setReady(id, true);
          break;
        case 'unready':
          await _repo.setReady(id, false);
          break;
        case 'deliver':
          await _pay(o, deliver: true);
          break;
        case 'pay':
          await _pay(o, deliver: false);
          break;
        case 'edit':
          final saved = await Navigator.of(context)
              .push<bool>(MaterialPageRoute(builder: (_) => BakeryOrderFormScreen(existing: o)));
          if (saved != true) return;
          break;
        case 'print':
          await _print(o);
          return;
        case 'share':
          await Share.share(await _slip(o), subject: 'Order ${o.number}');
          return;
        case 'call':
          await launchUrl(Uri(scheme: 'tel', path: o.phone));
          return;
        case 'cancel':
          await _cancel(o);
          break;
        case 'delete':
          final ok = await _confirm(Loc.t('Delete this order?', 'یہ آرڈر حذف کریں؟'));
          if (!ok) return;
          await _repo.deleteUnpaid(id);
          break;
      }
    } catch (e) {
      _toast(e.toString());
    }
    await _load();
  }

  Future<String> _slip(BakeryOrder o) async {
    final shop = (await UserRepository.instance.getSetting('shop_name'))?.trim() ?? '';
    final phone = (await UserRepository.instance.getSetting('shop_phone'))?.trim() ?? '';
    return orderSlipText(o, shopName: shop, shopPhone: phone);
  }

  Future<void> _print(BakeryOrder o) async {
    final err = await PrinterService.instance.printText(await _slip(o));
    _toast(err ?? Loc.t('Slip printed', 'پرچی پرنٹ ہو گئی'));
  }

  Future<bool> _confirm(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('No', 'نہیں'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(Loc.t('Yes', 'ہاں'))),
        ],
      ),
    );
    return r == true;
  }

  /// Payment / delivery dialog: raqam (default = poora baqi) + cash/bank.
  Future<void> _pay(BakeryOrder o, {required bool deliver}) async {
    final amount = TextEditingController(text: o.balance > 0 ? _n(o.balance) : '0');
    var method = 'cash';
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(deliver ? Loc.t('Deliver order', 'آرڈر ڈیلیور کریں') : Loc.t('Receive payment', 'رقم وصول کریں')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${Loc.t('Balance', 'باقی')}: ${_rs(o.balance)}'),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(labelText: Loc.t('Amount received now', 'ابھی وصول رقم')),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(Loc.t('Cash', 'کیش'))),
                ButtonSegment(value: 'bank', label: Text(Loc.t('Bank / Online', 'بینک / آن لائن'))),
              ],
              selected: {method},
              onSelectionChanged: (s) => setD(() => method = s.first),
            ),
            if (deliver)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  Loc.t('Anything left unpaid stays as balance on this closed order.',
                      'جو رقم نہ ملی وہ اس بند آرڈر پر باقی لکھی رہے گی۔'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('Cancel', 'منسوخ'))),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(Loc.t('Save', 'محفوظ کریں'))),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text.trim()) ?? -1;
    amount.dispose();
    if (res != true) return;
    if (value < 0) {
      _toast(Loc.t('Enter a valid amount', 'صحیح رقم لکھیں'));
      return;
    }
    await _repo.receive(o.id!, value, method: method, deliver: deliver);
    _toast(deliver ? Loc.t('Order delivered', 'آرڈر ڈیلیور ہو گیا') : Loc.t('Payment saved', 'رقم محفوظ ہو گئی'));
  }

  Future<void> _cancel(BakeryOrder o) async {
    final refund = TextEditingController(text: o.received > 0 ? _n(o.received) : '0');
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Loc.t('Cancel order?', 'آرڈر منسوخ کریں؟')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${Loc.t('Received so far', 'اب تک وصول')}: ${_rs(o.received)}'),
          const SizedBox(height: 10),
          TextField(
            controller: refund,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: Loc.t('Refund to customer (cash)', 'کسٹمر کو واپسی (کیش)'),
              helperText: Loc.t('0 = advance kept', '0 = ایڈوانس رکھ لیا'),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(Loc.t('Back', 'واپس'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _p.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(Loc.t('Cancel order', 'منسوخ کریں')),
          ),
        ],
      ),
    );
    final value = double.tryParse(refund.text.trim()) ?? 0;
    refund.dispose();
    if (res != true) return;
    await _repo.cancel(o.id!, refund: value);
    _toast(Loc.t('Order cancelled', 'آرڈر منسوخ ہو گیا'));
  }
}

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

// ====================================================================== form

/// Naya order / tabdeeli.
class BakeryOrderFormScreen extends StatefulWidget {
  const BakeryOrderFormScreen({super.key, this.existing});
  final BakeryOrder? existing;

  @override
  State<BakeryOrderFormScreen> createState() => _BakeryOrderFormScreenState();
}

class _BakeryOrderFormScreenState extends State<BakeryOrderFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _item = TextEditingController();
  final _flavour = TextEditingController();
  final _weight = TextEditingController();
  final _message = TextEditingController();
  final _notes = TextEditingController();
  final _address = TextEditingController();
  final _total = TextEditingController();
  final _advance = TextEditingController();

  String _weightUnit = 'lb';
  bool _home = false;
  String _method = 'cash';
  late DateTime _when;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static const _quickItems = <String>[
    'Birthday cake',
    'Wedding cake',
    'Custom design cake',
    'Cup cakes',
    'Pastries box',
    'Mithai box',
    'Bakery items (party)',
  ];

  static const _flavours = <String>[
    'Chocolate',
    'Vanilla',
    'Pineapple',
    'Strawberry',
    'Black Forest',
    'Red Velvet',
    'Coffee',
    'Mango',
  ];

  @override
  void initState() {
    super.initState();
    final o = widget.existing;
    if (o != null) {
      _name.text = o.customerName;
      _phone.text = o.phone;
      _item.text = o.item;
      _flavour.text = o.flavour;
      _weight.text = o.weight > 0 ? _n(o.weight) : '';
      _weightUnit = o.weightUnit.isEmpty ? 'lb' : o.weightUnit;
      _message.text = o.cakeMessage;
      _notes.text = o.notes;
      _home = o.homeDelivery;
      _address.text = o.address;
      _total.text = _n(o.total);
      _advance.text = _n(o.advance);
      _when = o.deliveryTime;
    } else {
      final t = DateTime.now().add(const Duration(days: 1));
      _when = DateTime(t.year, t.month, t.day, 17, 0); // kal shaam 5 baje
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _item, _flavour, _weight, _message, _notes, _address, _total, _advance]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _when.isBefore(now) ? now : _when,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null || !mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null || !mounted) return;
    setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_saving) return;
    final total = double.tryParse(_total.text.trim());
    final advance = _isEdit ? widget.existing!.advance : (double.tryParse(_advance.text.trim().isEmpty ? '0' : _advance.text.trim()));
    final err = validateOrder(customerName: _name.text, item: _item.text, total: total, advance: advance);
    if (err != null) {
      _toast(err);
      return;
    }
    final weight = double.tryParse(_weight.text.trim()) ?? 0;
    final o = BakeryOrder(
      id: widget.existing?.id,
      customerName: _name.text,
      phone: _phone.text,
      item: _item.text,
      flavour: _flavour.text,
      weight: weight.isFinite && weight > 0 ? weight : 0,
      weightUnit: _weightUnit,
      cakeMessage: _message.text,
      notes: _notes.text,
      homeDelivery: _home,
      address: _home ? _address.text : '',
      total: total!,
      advance: advance!,
      deliveryAt: _when.millisecondsSinceEpoch,
      createdAt: widget.existing?.createdAt ?? 0,
    );
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await BakeryOrderRepository.instance.update(o);
      } else {
        await BakeryOrderRepository.instance.create(o, advanceMethod: _method);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.toString());
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: ThemeManager.palette.fieldFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _gap() => const SizedBox(height: 12);

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: ThemeManager.palette.textMuted)),
      );

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final total = double.tryParse(_total.text.trim()) ?? 0;
    final adv = _isEdit ? widget.existing!.received : (double.tryParse(_advance.text.trim()) ?? 0);
    final bal = total - adv;
    const numKb = TextInputType.numberWithOptions(decimal: true);
    final numOnly = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.navy,
        foregroundColor: Colors.white,
        title: Text(_isEdit
            ? '${Loc.t('Edit Order', 'آرڈر میں تبدیلی')} ${widget.existing!.number}'
            : Loc.t('New Cake Order', 'نیا کیک آرڈر')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        _section(Loc.t('CUSTOMER', 'کسٹمر')),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _dec(Loc.t('Customer name *', 'کسٹمر کا نام *'))),
        _gap(),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec(Loc.t('Phone', 'فون'))),
        _section(Loc.t('ORDER', 'آرڈر')),
        TextField(controller: _item, decoration: _dec(Loc.t('Item *', 'آئٹم *'), hint: 'Birthday cake')),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final q in _quickItems)
            ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _item.text = q)),
        ]),
        _gap(),
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(controller: _flavour, decoration: _dec(Loc.t('Flavour', 'فلیور'))),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: Loc.t('Flavours', 'فلیورز'),
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            onSelected: (v) => setState(() => _flavour.text = v),
            itemBuilder: (_) => [for (final f in _flavours) PopupMenuItem(value: f, child: Text(f))],
          ),
        ]),
        _gap(),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _weight,
              keyboardType: numKb,
              inputFormatters: numOnly,
              decoration: _dec(Loc.t('Weight', 'وزن')),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'lb', label: Text('Pound')),
              ButtonSegment(value: 'kg', label: Text('Kg')),
            ],
            selected: {_weightUnit},
            onSelectionChanged: (s) => setState(() => _weightUnit = s.first),
          ),
        ]),
        _gap(),
        TextField(controller: _message, decoration: _dec(Loc.t('Message on cake', 'کیک پر لکھنا'), hint: 'Happy Birthday Ali')),
        _gap(),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: _dec(Loc.t('Design / notes', 'ڈیزائن / نوٹس'), hint: '2 tier, blue theme, photo on WhatsApp'),
        ),
        _section(Loc.t('DELIVERY', 'ڈیلیوری')),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(_dayFmt.format(_when)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(_timeFmt.format(_when)),
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _home,
          onChanged: (v) => setState(() => _home = v),
          title: Text(Loc.t('Home delivery', 'گھر پر ڈیلیوری')),
          subtitle: Text(_home ? Loc.t('We deliver', 'ہم پہنچائیں گے') : Loc.t('Customer picks up from shop', 'کسٹمر دکان سے لے گا')),
        ),
        if (_home) TextField(controller: _address, minLines: 1, maxLines: 3, decoration: _dec(Loc.t('Address', 'پتہ'))),
        _section(Loc.t('PAYMENT', 'ادائیگی')),
        TextField(
          controller: _total,
          keyboardType: numKb,
          inputFormatters: numOnly,
          onChanged: (_) => setState(() {}),
          decoration: _dec(Loc.t('Total price (Rs) *', 'کل قیمت (روپے) *')),
        ),
        _gap(),
        if (!_isEdit) ...[
          TextField(
            controller: _advance,
            keyboardType: numKb,
            inputFormatters: numOnly,
            onChanged: (_) => setState(() {}),
            decoration: _dec(Loc.t('Advance received now (Rs)', 'ابھی ایڈوانس وصول (روپے)')),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'cash', label: Text(Loc.t('Cash', 'کیش'))),
              ButtonSegment(value: 'bank', label: Text(Loc.t('Bank / Online', 'بینک / آن لائن'))),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
        ] else
          Text('${Loc.t('Already received', 'پہلے وصول')}: ${_rs(widget.existing!.received)}',
              style: TextStyle(color: p.textMuted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
          child: Row(children: [
            Text(Loc.t('Balance on delivery', 'ڈیلیوری پر باقی'), style: TextStyle(color: p.textMuted)),
            const Spacer(),
            Text(_rs(bal > 0 ? bal : 0), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.textDark)),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_isEdit ? Loc.t('SAVE CHANGES', 'تبدیلی محفوظ کریں') : Loc.t('BOOK ORDER', 'آرڈر بک کریں')),
          ),
        ),
      ),
    );
  }
}

// ====================================================================== summary

/// Mahine ka khulasa: kitne orders, kitni qeemat, kitna wusool, kitne cancel.
class BakeryOrderSummaryScreen extends StatefulWidget {
  const BakeryOrderSummaryScreen({super.key});

  @override
  State<BakeryOrderSummaryScreen> createState() => _BakeryOrderSummaryScreenState();
}

class _BakeryOrderSummaryScreenState extends State<BakeryOrderSummaryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  ({int orders, int delivered, int cancelled, double value, double received})? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await BakeryOrderRepository.instance.summary(_month, DateTime(_month.year, _month.month + 1));
    if (mounted) setState(() => _s = s);
  }

  void _shift(int m) {
    setState(() => _month = DateTime(_month.year, _month.month + m));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final s = _s;
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Text(l, style: TextStyle(color: p.textMuted, fontSize: 14.5)),
            const Spacer(),
            Text(v, style: TextStyle(color: p.textDark, fontWeight: FontWeight.bold, fontSize: 15.5)),
          ]),
        );
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.navy, foregroundColor: Colors.white, title: Text(Loc.t('Orders Summary', 'آرڈرز کا خلاصہ'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(DateFormat('MMMM yyyy').format(_month),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: p.textDark)),
          ),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: p.cardWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
          child: s == null
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              : Column(children: [
                  row(Loc.t('Orders (by delivery date)', 'آرڈرز (ڈیلیوری تاریخ)'), '${s.orders}'),
                  row(Loc.t('Delivered', 'ڈیلیور'), '${s.delivered}'),
                  row(Loc.t('Cancelled', 'منسوخ'), '${s.cancelled}'),
                  const Divider(),
                  row(Loc.t('Order value', 'آرڈرز کی قیمت'), _rs(s.value)),
                  row(Loc.t('Money received', 'وصول رقم'), _rs(s.received)),
                ]),
        ),
        const SizedBox(height: 12),
        Text(
          Loc.t('Order payments appear in Day Book and Cash as "Cake Order" income.',
              'آرڈر کی رقم روزنامچہ اور کیش میں "Cake Order" آمدنی کے طور پر نظر آتی ہے۔'),
          style: TextStyle(color: p.textMuted, fontSize: 12.5),
        ),
      ]),
    );
  }
}
