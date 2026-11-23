import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/dashboard_repository.dart';
import '../db/party_dashboard_repository.dart';
import '../desktop/desktop_prefs.dart';
import '../desktop/desktop_shell.dart';
import '../models/misc_entities.dart';
import '../models/product.dart';
import '../services/biometric.dart';
import '../services/crash_handler.dart';
import '../services/crash_reporter.dart';
import '../services/session.dart';
import '../sync/settings_sync.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import '../widgets/party_quick_add_menu.dart' show showPartyPickerForPayment;
import '../widgets/role_guard.dart';
import 'backup_export_screen.dart';
import '../license/license_screen.dart';
import '../license/license_service.dart';
import 'bakery_orders_screen.dart';
import 'production_screen.dart';
import 'wastage_screen.dart';
import '../db/bakery_order_repository.dart';
import '../db/production_repository.dart';
import '../db/wastage_repository.dart';
import '../widgets/bakery_premium.dart';
import 'daily_bills_screen.dart';
import 'day_book_screen.dart';
import 'item_search_screen.dart';
import 'items_screen.dart';
import 'login_screen.dart';
import 'party_dashboard_screen.dart';
import 'party_transaction_screen.dart';
import 'purchase_screen.dart';
import 'sale_screen.dart';
import 'settings_screen.dart';
import 'stock_report_screen.dart';

/// Ek dashboard card. [open] aur [onTap] dono null => abhi port nahi hua ("Coming soon").
class _Action {
  final String en, ur, subEn, subUr;
  final IconData icon;
  final Color bg, fg;
  final Widget Function()? open;
  final VoidCallback? onTap;

  /// > 0 => icon ke saath chhota laal number (jaise overdue parties ki ginti).
  final int badge;
  const _Action(this.en, this.ur, this.subEn, this.subUr, this.icon, this.bg, this.fg,
      {this.open, this.onTap, this.badge = 0});
}

/// Mirrors MainActivity.kt — header (Settings / dark toggle / Quick Switch), live item-rate search,
/// Customer/Supplier search, QUICK ACTIONS grid, DUES SUMMARY (You'll get / give).
///
/// Data + faislay `lib/db/dashboard_repository.dart` mein hain (pure functions, test/dashboard_test.dart).
/// Kotlin Dashboard par sirf quick actions hain; baqi screens (Reports, Products, Zakat ...) Kotlin mein
/// Settings/Reports ke andar hain — Flutter mein bhi wahin (SettingsScreen link rows + ReportsScreen hub).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _am = {'admin', 'manager'};
  static const _admin = {'admin'};

  // Kotlin: get/give green & red semantic hain — theme badalne par bhi wahi rehte hain.
  static const _partyGreen = Color(0xFF1B8A4A);
  static const _partyRed = Color(0xFFD32F4A);
  static const _partyRedBg = Color(0xFFFCEBEB);

  static const _defaultShopName = 'Hanna Bakery';

  AppPalette get _p => ThemeManager.palette;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode(); // PC: Ctrl+F
  List<Product>? _products; // cache; doosri screen se wapas aane par reset
  List<Product> _matches = const [];
  String _query = '';

  // Party (Customer + Supplier) nateeje — ab wahi ek search bar (_searchCtrl) chalata hai.
  List<PartyRow>? _parties; // cache; doosri screen se wapas aane par reset
  List<PartyRow> _partyMatches = const [];
  bool _showCustomers = true;
  bool _showSuppliers = true;

  double _toGet = 0;
  double _toGive = 0;
  BakeryOrderCounts _orders = const BakeryOrderCounts(); // aaj / kal ke cake orders
  List<BakeryOrder> _next = const []; // agle khule orders (Bake Board)
  DashboardTotals? _today; // aaj ki sale (+ admin ko profit)
  double _wasteToday = 0; // aaj ka wastage nuqsan (cost)
  int _bakedToday = 0; // aaj ki production entries
  int _pending = 0;
  String _shopName = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    DesktopShell.rootShown.addListener(_onRootShown);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLastCrash();
      await _licenseGuard();
    });
  }

  /// License / trial dobara check (app din bhar khuli reh sakti hai). Khatam => License screen; 7 din ya kam => yaad dihani.
  Future<void> _licenseGuard() async {
    final s = await LicenseService.check();
    if (!mounted) return;
    if (!s.allowed) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LicenseScreen(gate: true)), (_) => false);
      return;
    }
    await maybeShowLicenseWarning(context);
  }

  /// Kotlin `showCrashDialog`: pichli baar crash hui ho to log dikhao (Share / Copy / Dismiss).
  Future<void> _checkLastCrash() async {
    final text = await CrashHandler.getLastCrash();
    if (text == null || !mounted) return;
    // Cloud Sync juda ho to developer ko khud (Firestore crash_reports) — dialog ka intezar kiye baghair.
    CrashReporter.uploadIfNew(text).ignore();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(Loc.t('App crashed last time', 'پچھلی بار ایپ کریش ہوئی تھی')),
        content: SingleChildScrollView(
          child: SelectableText(CrashHandler.preview(text), style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await launchUrl(CrashReporter.whatsAppUri(text), mode: LaunchMode.externalApplication);
              } catch (_) {}
              await CrashHandler.clearLastCrash();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(Loc.t('Send to developer', 'ڈیولپر کو بھیجیں')),
          ),
          TextButton(
            onPressed: () async {
              await Share.share(text, subject: 'Hanna Bakery POS Crash Log');
              await CrashHandler.clearLastCrash();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(Loc.t('Share', 'شیئر کریں')),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(Loc.t('Copied', 'کاپی ہو گیا'))),
                );
              }
            },
            child: Text(Loc.t('Copy', 'کاپی')),
          ),
          TextButton(
            onPressed: () async {
              await CrashHandler.clearLastCrash();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(Loc.t('Dismiss', 'برخاست کریں')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    DesktopShell.rootShown.removeListener(_onRootShown);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  /// Kotlin onResume: loadDashboard + loadShopName + loadPartySummary + sync pending.
  /// Har hissa alag try mein — ek fail ho to baqi numbers phir bhi dikhen.
  Future<void> _refresh() async {
    final repo = DashboardRepository.instance;
    String? error;

    ({double toGet, double toGive})? party;
    int? pending;
    String? shop;
    BakeryOrderCounts? orders;
    List<BakeryOrder>? next;
    DashboardTotals? today;
    double? waste;
    int? baked;
    // Bakery hisse ka masla baqi dashboard ko na rokay: alag try, error toast nahi.
    try {
      final open = await BakeryOrderRepository.instance.open();
      orders = countOrders(open, DateTime.now());
      next = open.take(12).toList();
    } catch (_) {}
    try {
      today = await repo.todayTotals();
    } catch (_) {}
    try {
      final n = DateTime.now();
      final from = DateTime(n.year, n.month, n.day);
      final to = DateTime(n.year, n.month, n.day + 1);
      if (Session.isAdminOrManager) {
        waste = (await WastageRepository.instance.between(from, to)).fold<double>(0, (a, r) => a + r.loss);
        baked = (await ProductionRepository.instance.log(from, to)).length;
      }
    } catch (_) {}
    try {
      party = await repo.partyTotalsNow();
    } catch (e) {
      error ??= e.toString();
    }
    try {
      pending = await repo.pendingSyncCount();
    } catch (e) {
      error ??= e.toString();
    }
    try {
      shop = await repo.shopName();
    } catch (e) {
      error ??= e.toString();
    }
    if (!mounted) return;
    setState(() {
      if (party != null) {
        _toGet = party.toGet;
        _toGive = party.toGive;
      }
      if (pending != null) _pending = pending;
      if (shop != null) _shopName = shop;
      if (orders != null) _orders = orders;
      if (next != null) _next = next;
      if (today != null) _today = today;
      if (waste != null) _wasteToday = waste;
      if (baked != null) _bakedToday = baked;
    });
    if (error != null) _toast(error);
  }

  /// Ek hi search bar: items (rate) AUR parties (customer / supplier) dono ek sath dhundta hai.
  Future<void> _onSearch(String q) async {
    final t = q.trim();
    setState(() => _query = t);
    if (t.isEmpty) {
      setState(() {
        _matches = const [];
        _partyMatches = const [];
      });
      return;
    }
    try {
      _products ??= await DashboardRepository.instance.loadProducts();
    } catch (e) {
      _toast(e.toString());
      return;
    }
    // Parties ka load fail ho jaye to bhi items dikhen.
    try {
      _parties ??= await PartyDashboardRepository.instance.loadParties();
    } catch (_) {}
    // Is dauran user ne aur type kar diya ho to purana jawab na dikhayen.
    if (!mounted || _searchCtrl.text.trim() != t) return;
    setState(() {
      _matches = dashboardSearch(_products!, t);
      _partyMatches = _parties == null
          ? const []
          : dashboardPartySearch(_parties!, t, customers: _showCustomers, suppliers: _showSuppliers);
    });
  }

  /// Header ka Sync button: Settings wala Sync Now (internet nahi => message). Baad mein dashboard refresh.
  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final summary = await SettingsSync.syncNow();
      if (!mounted) return;
      _toast(summary ?? Loc.t('No internet connection', 'انٹرنیٹ کنکشن نہیں'));
    } catch (_) {
      if (mounted) _toast(Loc.t('Sync failed', 'سنک ناکام'));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
    if (!mounted) return;
    _products = null;
    _parties = null;
    await _refresh();
    if (_query.isNotEmpty) _onSearch(_searchCtrl.text);
  }

  bool get _canSeeSuppliers => _am.contains(Session.role); // cashier ko supplier screen band

  /// PC sidebar se wapas Dashboard par aaye (yahan ka `_push` nahi chala) — numbers dobara padho.
  void _onRootShown() {
    if (!mounted) return;
    _products = null;
    _parties = null;
    _refresh();
    if (_query.isNotEmpty) _onSearch(_searchCtrl.text);
    _licenseGuard();
  }

  // ------------------------------------------------------------ navigation

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    _products = null; // products doosri screen par badal sakte hain
    _parties = null; // baqaya badal gaya ho sakta hai
    _refresh();
    if (_query.isNotEmpty) _onSearch(_searchCtrl.text);
  }

  /// Payment Received / Made: parties load karke seedha picker kholta hai; chunne par us party ka
  /// payment dialog (baqaya "Full due" ke saath) khulta hai.
  Future<void> _quickPayment({required bool forCustomer}) async {
    try {
      final parties = await PartyDashboardRepository.instance.loadParties();
      if (!mounted) return;
      await showPartyPickerForPayment(
        context,
        parties: parties,
        forCustomer: forCustomer,
        onPicked: (r) => _push(PartyTransactionScreen(
          partyId: r.id,
          partyName: r.name,
          isCustomer: r.isCustomer,
          openPayment: true,
          dueHint: r.closing > 0 ? r.closing : 0,
        )),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _run(_Action a) {
    if (a.onTap != null) {
      a.onTap!();
    } else if (a.open != null) {
      _push(a.open!());
    } else {
      _toast(Loc.t('Coming soon', 'جلد آ رہا ہے'));
    }
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------ quick switch

  Future<void> _openQuickSwitch() async {
    final List<User> users;
    try {
      users = await DashboardRepository.instance.activeUsers();
    } catch (e) {
      _toast(e.toString());
      return;
    }
    if (!mounted || users.isEmpty) return;
    final picked = await showDialog<User>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Loc.t('Switch User', 'یوزر تبدیل کریں')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [for (final u in users) _switchRow(ctx, u)],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Loc.t('Cancel', 'منسوخ کریں')))],
      ),
    );
    if (picked == null || !mounted) return;
    await _attemptSwitch(picked);
  }

  Widget _switchRow(BuildContext ctx, User u) {
    final p = _p;
    final isCurrent = u.username == Session.username;
    final roleColor = Color(roleColorValue(u.role));
    final roleLabel = u.role.isEmpty ? '' : u.role[0].toUpperCase() + u.role.substring(1);
    return Opacity(
      opacity: isCurrent ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: p.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isCurrent ? null : () => Navigator.pop(ctx, u),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: roleColor,
                child: Text(
                  u.displayName.isEmpty ? '?' : u.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isCurrent ? '${u.displayName} (${Loc.t('Current', 'موجودہ')})' : u.displayName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: p.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(roleLabel, style: TextStyle(fontSize: 11.5, color: roleColor)),
                ]),
              ),
              if (!isCurrent) Icon(Icons.chevron_right, color: p.textMuted),
            ]),
          ),
        ),
      ),
    );
  }

  /// Kotlin attemptQuickSwitch(): pehle fingerprint; na ho / cancel ho / fail ho to us user ka password.
  Future<void> _attemptSwitch(User user) async {
    if (await Biometric.isAvailable()) {
      final ok = await Biometric.authenticate(
        reason: Loc.t('Verify fingerprint to switch to ${user.displayName}',
            '${user.displayName} کے اکاؤنٹ پر جانے کے لیے فنگر پرنٹ سے تصدیق کریں'),
      );
      if (!mounted) return;
      if (ok) {
        await _completeSwitch(user);
        return;
      }
    }
    await _askPassword(user);
  }

  Future<void> _askPassword(User user) async {
    final typed = await showDialog<String>(context: context, builder: (_) => _PasswordDialog(name: user.displayName));
    if (typed == null || !mounted) return;
    final bool ok;
    try {
      ok = await DashboardRepository.instance.verifySwitchPassword(user, typed);
    } catch (e) {
      _toast(e.toString());
      return;
    }
    if (!mounted) return;
    if (ok) {
      await _completeSwitch(user);
    } else {
      _toast(Loc.t('Wrong password', 'غلط پاس ورڈ'));
    }
  }

  /// Kotlin completeQuickSwitch(): session badlo aur dashboard naye role ke hisaab se dobara banao (recreate()).
  Future<void> _completeSwitch(User user) async {
    await DashboardRepository.instance.completeSwitch(user);
    if (!mounted) return;
    _toast(Loc.t('Switched to ${user.displayName}', '${user.displayName} پر سوئچ ہو گیا'));
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (_) => false);
  }

  // ---------------------------------------------------------------- actions

  /// Kotlin `quickActions` list, usi tarteeb mein.
  List<_Action> _quickActions(AppPalette p) {
    final role = Session.role;
    return [
      _Action('Sale', 'سیل', 'Start a new sale', 'نئی سیل شروع کریں', Icons.shopping_cart_outlined, p.flatPurpleBg, p.flatPurpleFg,
          open: () => const SaleScreen()),
      _Action('Quick Sale', 'کوئیک سیل', 'Fast single-item sale', 'ایک آئٹم کی تیز سیل', Icons.timer_outlined, p.flatPurpleBg,
          p.flatPurpleFg,
          open: () => const SaleScreen(openQuickSale: true)),
      if (role == 'admin')
        _Action('Purchase', 'خریداری', 'Record a purchase', 'خریداری درج کریں', Icons.inventory_2_outlined, p.flatCoralBg, p.flatCoralFg,
            open: () => const RoleGuard(allowed: _admin, child: PurchaseScreen())),
      // Daily Bills (admin/manager) ab seedha dashboard par; Cash in/out dashboard se hata diya
      // (Settings -> Cash & Bank aur Customers & Suppliers se ab bhi khulta hai).
      if (_am.contains(role))
        _Action('Daily Bills', 'روزانہ بلز', 'One bill per customer per day', 'ہر کسٹمر کا دن کا ایک بل', Icons.receipt_long_outlined,
            p.flatAmberBg, p.flatAmberFg,
            open: () => const DailyBillsScreen()),
      // Payments ke do alag tiles: ek tap => seedha party picker (beech ki Customers screen / chooser khatam).
      _Action('Payment\nReceived', 'ادائیگی\nوصول', 'Money received from a customer', 'کسٹمر سے رقم وصول', Icons.south_west, p.flatTealBg,
          p.flatTealFg,
          onTap: () => _quickPayment(forCustomer: true)),
      // Supplier screen cashier ke liye band (PartyTransactionScreen ki tarah).
      if (_am.contains(role))
        _Action('Payment\nMade', 'ادائیگی\nادا', 'Money paid to a supplier', 'سپلائر کو رقم ادا', Icons.north_east, p.flatCoralBg,
            p.flatCoralFg,
            onTap: () => _quickPayment(forCustomer: false)),
      // Bakery: cake / custom orders (advance + delivery date). Badge = aaj ki delivery + der wale.
      _Action('Cake Orders', 'کیک آرڈرز', 'Bookings, advance & delivery', 'بکنگ، ایڈوانس اور ڈیلیوری', Icons.cake_outlined,
          p.flatPinkBg, p.flatPinkFg,
          open: () => const BakeryOrdersScreen(), badge: _orders.dueToday + _orders.late),
      if (_am.contains(role))
        _Action('Production', 'پروڈکشن', 'Recipes & daily baking', 'ریسپی اور روزانہ تیاری', Icons.bakery_dining_outlined,
            p.flatAmberBg, p.flatAmberFg,
            open: () => const ProductionScreen()),
      if (_am.contains(role))
        _Action('Wastage', 'ویسٹیج', 'Stale / damaged goods & loss', 'باسی / خراب مال اور نقصان', Icons.delete_sweep_outlined,
            _partyRedBg, _partyRed,
            open: () => const WastageScreen()),
      _Action('Customers &\nSuppliers', 'گاہک اور\nسپلائر', 'Manage ledgers & dues', 'کھاتے اور بقایا', Icons.people_outline, p.flatPinkBg,
          p.flatPinkFg,
          open: () => const PartyDashboardScreen()),
      _Action('Low Stock', 'کم اسٹاک', 'Items needing restock', 'دوبارہ منگوانے والی اشیاء', Icons.warning_amber_rounded, _partyRedBg,
          _partyRed,
          open: () => const StockReportScreen(lowStockOnly: true)),
      // Kotlin jaisa: Items tile sab roles ko (koi gate nahi). ItemsScreen ke andar cashier ko cost nahi
      // dikhta aur add/edit/delete sirf admin (lib/screens/items_screen.dart, items_repository.dart).
      _Action('Items', 'آئٹمز', 'Products, categories & units', 'پروڈکٹس، کیٹیگریز اور یونٹس', Icons.list_alt, p.flatBlueBg, p.flatBlueFg,
          open: () => const ItemsScreen()),
      if (_am.contains(role))
        _Action('Backup', 'بیک اپ', 'Export data (CSV + PDF)', 'ڈیٹا ایکسپورٹ', Icons.save_outlined, p.flatBlueBg, p.flatBlueFg,
            open: () => const BackupExportScreen()),
      _Action('Day book', 'روزنامچہ', 'View daily ledger', 'روزانہ کھاتہ', Icons.menu_book_outlined, p.flatTealBg, p.flatTealFg,
          open: () => const DayBookScreen()),
      if (showsLogoutTile(role))
        _Action('Logout', 'لاگ آؤٹ', 'Sign out of this session', 'اس سیشن سے سائن آؤٹ کریں', Icons.logout, _partyRedBg, _partyRed,
            onTap: _logout),
    ];
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final mq = MediaQuery.of(context);
    if (DesktopPrefs.wide(mq.size.width)) return _desktop(p, mq);
    final cols = dashboardColumns(mq.size.width);
    return Scaffold(
      backgroundColor: p.bg,
      body: RefreshIndicator(
        color: ThemeManager.gold,
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, mq.padding.top + 10, 12, 28 + mq.padding.bottom),
          children: [
            _hero(p, wide: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_query.isNotEmpty) _unifiedResults(p),
                if (_next.isNotEmpty) ...[
                  _bakeBoardTitle(),
                  _deliveryStrip(p),
                ],
                PremiumSection(Loc.t("TODAY'S PERFORMANCE", 'آج کی کارکردگی')),
                _kpis(p, cols),
                PremiumSection(Loc.t('BAKERY CONTROL', 'بیکری کنٹرول')),
                _grid(_quickActions(p), cols, p),
                if (_pending > 0) _syncPendingLabel(),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ PC (Windows) layout

  /// PC: upar bara hero (dukaan, search, aaj ke figures, gold CTAs); neeche baayen KPIs + Bakery Control grid,
  /// daayen Bake Board (agle orders). Data / actions wahi jo phone par — sirf tarteeb alag.
  Widget _desktop(AppPalette p, MediaQueryData mq) {
    final w = mq.size.width;
    final sideW = w >= 1250 ? 380.0 : 330.0;
    final mainW = w - sideW - 24 * 3;
    final cols = mainW >= 1000 ? 6 : (mainW >= 820 ? 5 : (mainW >= 620 ? 4 : 3));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.f5): _onRootShown,
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Scaffold(
          backgroundColor: p.bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(p, wide: true),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_query.isNotEmpty) _unifiedResults(p),
                    PremiumSection(Loc.t("TODAY'S PERFORMANCE", 'آج کی کارکردگی')),
                    _kpis(p, cols >= 5 ? 3 : 2),
                    PremiumSection(Loc.t('BAKERY CONTROL', 'بیکری کنٹرول')),
                    // Text size (Ctrl +) ke saath card bhi lamba — 100% par phone jitna (146).
                    _grid(_quickActions(p), cols, p, extent: 50 + 96 * mq.textScaler.scale(1)),
                  ]),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: sideW,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _bakeBoardTitle(),
                    if (_next.isEmpty)
                      _emptyBoard(p)
                    else
                      for (final o in _next.take(8))
                        Padding(padding: const EdgeInsets.only(bottom: 10), child: _deliveryCard(p, o, width: null)),
                    if (_pending > 0) _syncPendingLabel(),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ hero

  static final _money = NumberFormat('#,##0');
  String _rs(double v) => 'Rs ${_money.format(v.round())}';

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return Loc.t('Good morning', 'صبح بخیر');
    if (h < 17) return Loc.t('Good afternoon', 'سلام');
    return Loc.t('Good evening', 'شام بخیر');
  }

  /// Executive hero: greeting, dukaan, tareekh, aaj ke 3 figures, gold CTAs aur search.
  Widget _hero(AppPalette p, {required bool wide}) {
    final role = Session.role;
    final roleLabel = role.isEmpty ? '' : role.toUpperCase();
    final user = (Session.username ?? '').trim();
    final shop = (_shopName.isEmpty ? _defaultShopName : _shopName).toUpperCase();
    final date = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    final controls = Row(children: [
      GlassIconButton(
          icon: Icons.settings_outlined, tooltip: Loc.t('Settings', 'سیٹنگز'), onTap: () => _push(const SettingsScreen())),
      const SizedBox(width: 8),
      GlassIconButton(
          icon: Icons.sync,
          tooltip: Loc.t('Sync now', 'ابھی سنک کریں'),
          onTap: _syncing ? null : _syncNow,
          busy: _syncing,
          dot: _pending > 0),
      const SizedBox(width: 8),
      GlassIconButton(icon: Icons.swap_horiz, tooltip: Loc.t('Switch user', 'یوزر تبدیل کریں'), onTap: _openQuickSwitch),
      if (wide) ...[
        const SizedBox(width: 8),
        GlassIconButton(icon: Icons.refresh, tooltip: Loc.t('Refresh (F5)', 'ریفریش (F5)'), onTap: _onRootShown),
      ],
    ]);

    final roleChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeManager.gold.withValues(alpha: 0.6)),
        color: ThemeManager.gold.withValues(alpha: 0.10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.workspace_premium, size: 15, color: ThemeManager.gold),
        const SizedBox(width: 6),
        Text(roleLabel,
            style: const TextStyle(color: ThemeManager.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
      ]),
    );

    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_greeting()}${user.isEmpty ? '' : ', $user'}',
          style: const TextStyle(color: ThemeManager.gold, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 4),
      Text(shop,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: ThemeManager.cream, fontSize: wide ? 26 : 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 3),
      Text('$date   •   ${Loc.t('BAKERY POS', 'بیکری POS')}',
          style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.55), fontSize: 12, letterSpacing: 0.4)),
    ]);

    final dueNow = _orders.late + _orders.dueToday;
    final figures = Row(children: [
      Expanded(child: HeroFigure(value: _rs(_today?.sale ?? 0), label: Loc.t("Today's sale", 'آج کی سیل'), accent: true)),
      Expanded(
        child: HeroFigure(
          value: '$dueNow',
          label: _orders.late > 0
              ? Loc.t('Orders due (${_orders.late} late)', 'آرڈرز (${_orders.late} لیٹ)')
              : Loc.t('Orders due today', 'آج کے آرڈرز'),
        ),
      ),
      Expanded(child: HeroFigure(value: _rs(_orders.balanceDue), label: Loc.t('Order balance', 'آرڈر باقی'))),
    ]);

    final pills = Wrap(spacing: 10, runSpacing: 10, children: [
      GoldPill(icon: Icons.point_of_sale, label: Loc.t('New Sale', 'نئی سیل'), onTap: () => _push(const SaleScreen())),
      GoldPill(
          icon: Icons.cake_outlined,
          label: Loc.t('Cake Order', 'کیک آرڈر'),
          onTap: () => _push(const BakeryOrderFormScreen())),
      if (_am.contains(Session.role))
        GoldPill(
            icon: Icons.bakery_dining_outlined,
            label: Loc.t('Bake', 'تیاری'),
            outlined: true,
            onTap: () => _push(const ProductionScreen())),
      if (_am.contains(Session.role))
        GoldPill(
            icon: Icons.delete_sweep_outlined,
            label: Loc.t('Wastage', 'ویسٹیج'),
            outlined: true,
            onTap: () => _push(const WastageScreen())),
    ]);

    if (wide) {
      return BakeryHero(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: title),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(top: 4), child: _searchBar(p, onDark: true))),
            const SizedBox(width: 16),
            controls,
            const SizedBox(width: 12),
            roleChip,
          ]),
          const SizedBox(height: 22),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 5, child: figures),
            const SizedBox(width: 24),
            Expanded(flex: 5, child: Align(alignment: AlignmentDirectional.centerEnd, child: pills)),
          ]),
        ]),
      );
    }
    return BakeryHero(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [controls, const Spacer(), roleChip]),
        const SizedBox(height: 18),
        title,
        const SizedBox(height: 18),
        figures,
        const SizedBox(height: 18),
        pills,
        const SizedBox(height: 16),
        _searchBar(p, onDark: true),
      ]),
    );
  }

  // ------------------------------------------------------------ bake board (agle orders)

  Widget _bakeBoardTitle() => PremiumSection(
        Loc.t("TODAY'S BAKE BOARD", 'آج کا بیک بورڈ'),
        trailing: TextButton(
          onPressed: () => _push(const BakeryOrdersScreen()),
          child: Text(Loc.t('All orders', 'سب آرڈرز')),
        ),
      );

  Widget _emptyBoard(AppPalette p) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: p.cardWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.border)),
        child: Row(children: [
          Icon(Icons.cake_outlined, color: p.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(Loc.t('No open cake orders', 'کوئی کھلا کیک آرڈر نہیں'), style: TextStyle(color: p.textMuted))),
        ]),
      );

  Widget _deliveryStrip(AppPalette p) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _next.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _deliveryCard(p, _next[i], width: 236),
        ),
      );

  /// Ek order: waqt chip (gold), status, customer, item, baqi raqam.
  Widget _deliveryCard(AppPalette p, BakeryOrder o, {double? width}) {
    final now = DateTime.now();
    final t = o.deliveryTime;
    final today = DateTime(now.year, now.month, now.day);
    final late = t.isBefore(now);
    final day = late
        ? Loc.t('LATE', 'لیٹ')
        : (t.isBefore(today.add(const Duration(days: 1)))
            ? Loc.t('TODAY', 'آج')
            : (t.isBefore(today.add(const Duration(days: 2))) ? Loc.t('TOMORROW', 'کل') : DateFormat('d MMM').format(t)));
    final ready = o.status == BakeryOrderStatus.ready;
    final accent = late ? p.red : (ready ? p.flatTealFg : p.teal);
    return SizedBox(
      width: width,
      height: 150,
      child: Material(
        color: p.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: late ? p.red.withValues(alpha: 0.5) : p.border),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onTap: () => _push(const BakeryOrdersScreen()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: Text('$day  ${DateFormat('h:mm a').format(t)}',
                      style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                ),
                const Spacer(),
                Icon(ready ? Icons.check_circle : (o.homeDelivery ? Icons.delivery_dining : Icons.storefront_outlined),
                    size: 18, color: ready ? p.flatTealFg : p.textMuted),
              ]),
              const SizedBox(height: 10),
              Text(o.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.textDark)),
              const SizedBox(height: 2),
              Text(
                [o.item, if (o.weight > 0) '${o.weight == o.weight.roundToDouble() ? o.weight.round() : o.weight} ${o.weightUnit}']
                    .join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: p.textMuted),
              ),
              const Spacer(),
              Row(children: [
                Text(o.number, style: TextStyle(fontSize: 11, color: p.textMuted, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  o.balance > 0 ? '${Loc.t('Due', 'باقی')} ${_rs(o.balance)}' : Loc.t('PAID', 'ادا شدہ'),
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w900, color: o.balance > 0 ? p.red : p.flatTealFg),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ KPIs

  Widget _kpis(AppPalette p, int cols) {
    final tiles = <Widget>[
      KpiTile(
        icon: Icons.south_west,
        label: Loc.t("You'll get", 'آپ کو ملنا ہے'),
        value: _rs(_toGet),
        color: p.flatTealFg,
        soft: p.flatTealBg,
        onTap: () => _push(const PartyDashboardScreen()),
      ),
      KpiTile(
        icon: Icons.north_east,
        label: Loc.t("You'll give", 'آپ کو دینا ہے'),
        value: _rs(_toGive),
        color: p.red,
        soft: p.flatCoralBg,
        onTap: () => _push(const PartyDashboardScreen()),
      ),
      KpiTile(
        icon: Icons.cake_outlined,
        label: Loc.t('Open cake orders', 'کھلے کیک آرڈرز'),
        value: '${_orders.open}',
        hint: Loc.t('${_orders.ready} ready • ${_orders.dueTomorrow} tomorrow', '${_orders.ready} تیار • ${_orders.dueTomorrow} کل'),
        color: p.flatPinkFg,
        soft: p.flatPinkBg,
        onTap: () => _push(const BakeryOrdersScreen()),
      ),
      if (_today?.profit != null)
        KpiTile(
          icon: Icons.trending_up,
          label: Loc.t("Today's profit", 'آج کا منافع'),
          value: _rs(_today!.profit!),
          hint: Loc.t('Sale − cost of goods', 'سیل − مال کی لاگت'),
          color: p.flatAmberFg,
          soft: p.flatAmberBg,
        ),
      if (_am.contains(Session.role))
        KpiTile(
          icon: Icons.bakery_dining_outlined,
          label: Loc.t('Baked today', 'آج تیار ہوا'),
          value: '$_bakedToday',
          hint: Loc.t('production entries', 'پروڈکشن اندراج'),
          color: p.flatAmberFg,
          soft: p.flatAmberBg,
          onTap: () => _push(const ProductionScreen()),
        ),
      if (_am.contains(Session.role))
        KpiTile(
          icon: Icons.delete_sweep_outlined,
          label: Loc.t('Wastage today', 'آج کا ویسٹیج'),
          value: _rs(_wasteToday),
          hint: Loc.t('loss at cost', 'لاگت پر نقصان'),
          color: p.red,
          soft: p.flatCoralBg,
          onTap: () => _push(const WastageScreen()),
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final n = cols < 2 ? 2 : (cols > 3 ? 3 : cols);
      final w = (c.maxWidth - (n - 1) * 12) / n;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }

  Widget _searchBar(AppPalette p, {bool onDark = false}) {
    final fg = onDark ? ThemeManager.cream : p.textDark;
    final muted = onDark ? ThemeManager.cream.withValues(alpha: 0.5) : p.textMuted;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.07) : p.cardWhite,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: onDark ? ThemeManager.gold.withValues(alpha: 0.30) : p.border),
      ),
      child: Row(children: [
        Icon(Icons.search, size: 20, color: onDark ? ThemeManager.gold : p.teal),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            cursorColor: ThemeManager.gold,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: fg),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: _canSeeSuppliers
                  ? Loc.t('Search item, customer, supplier…', 'آئٹم، کسٹمر، سپلائر سرچ کریں…')
                  : Loc.t('Search item, customer…', 'آئٹم، کسٹمر سرچ کریں…'),
              hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: muted),
            onPressed: () {
              _searchCtrl.clear();
              _onSearch('');
            },
          ),
      ]),
    );
  }

  /// Ek search ke nateeje: pehle Items (rate), phir Parties (chips ke sath).
  Widget _unifiedResults(AppPalette p) {
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.bold, color: p.textMuted)),
        );
    Widget empty(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          child: Text(text, style: TextStyle(fontSize: 13, color: p.textMuted)),
        );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: p.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header(Loc.t('ITEMS', 'آئٹمز')),
        if (_matches.isEmpty) empty(Loc.t('No matching items', 'کوئی آئٹم نہیں ملا')) else _itemRows(p),
        Divider(height: 1, thickness: 1, color: p.border),
        header(Loc.t('PARTIES', 'پارٹیاں')),
        if (_canSeeSuppliers)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Wrap(spacing: 8, children: [
              _partyChip(p, Loc.t('All', 'سب'), _showCustomers && _showSuppliers, () => _setPartyFilter(true, true)),
              _partyChip(p, Loc.t('Customers', 'کسٹمرز'), _showCustomers && !_showSuppliers, () => _setPartyFilter(true, false)),
              _partyChip(p, Loc.t('Suppliers', 'سپلائرز'), !_showCustomers && _showSuppliers, () => _setPartyFilter(false, true)),
            ]),
          ),
        if (_partyMatches.isEmpty)
          empty(Loc.t('No matching party', 'کوئی پارٹی نہیں ملی'))
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _partyResults(p)),
        const SizedBox(height: 6),
      ]),
    );
  }

  /// Kotlin runItemSearch(): pehle 6 match; tap => ItemSearchScreen usi item par khuli hui.
  Widget _itemRows(AppPalette p) {
    return Column(children: [
      for (var i = 0; i < _matches.length; i++) ...[
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _push(ItemSearchScreen(preselectBarcode: _matches[i].barcode)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(_matches[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: p.textDark)),
              ),
              const SizedBox(width: 10),
              Text(dashboardAmount(_matches[i].salePrice),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: p.flatBlueFg)),
            ]),
          ),
        ),
        if (i != _matches.length - 1) Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: p.border),
      ],
    ]);
  }

  void _setPartyFilter(bool customers, bool suppliers) {
    setState(() {
      _showCustomers = customers;
      _showSuppliers = suppliers;
    });
    if (_query.isNotEmpty) _onSearch(_searchCtrl.text);
  }

  Widget _partyChip(AppPalette p, String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? p.flatPinkFg : p.textMuted)),
      selected: selected,
      selectedColor: p.flatPinkBg,
      backgroundColor: p.cardWhite,
      side: BorderSide(color: p.border),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }

  Widget _partyResults(AppPalette p) {
    if (_partyMatches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(Loc.t('No matching party', 'کوئی پارٹی نہیں ملی'), style: TextStyle(fontSize: 13, color: p.textMuted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(children: [
        for (var i = 0; i < _partyMatches.length; i++) ...[
          _partyRow(p, _partyMatches[i]),
          if (i != _partyMatches.length - 1) Divider(height: 1, thickness: 1, color: p.border),
        ],
      ]),
    );
  }

  Widget _partyRow(AppPalette p, PartyRow r) {
    final settled = r.isSettled;
    final color = settled ? p.textMuted : (r.isGive ? _partyRed : _partyGreen);
    final status = settled
        ? Loc.t('Settled', 'برابر')
        : (r.isGive ? Loc.t("You'll give", 'دینا ہے') : Loc.t("You'll get", 'ملنا ہے'));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(PartyTransactionScreen(
        partyId: r.id,
        partyName: r.name,
        isCustomer: r.isCustomer,
        dueHint: r.closing > 0 ? r.closing : 0,
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: p.textDark)),
              const SizedBox(height: 3),
              Text(
                [
                  r.isCustomer ? Loc.t('Customer', 'کسٹمر') : Loc.t('Supplier', 'سپلائر'),
                  if (r.phone.isNotEmpty) r.phone,
                ].join(' • '),
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(dashboardAmount(r.closing.abs()), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            Text(status, style: TextStyle(fontSize: 11, color: color)),
          ]),
        ]),
      ),
    );
  }

  /// sync_queue mein na bheji hui rows — tap => Settings (Kotlin: Sync History wahin hai).
  Widget _syncPendingLabel() {
    final msg = syncPendingMessage(_pending, urdu: Loc.isUrdu);
    if (msg == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _push(const SettingsScreen()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text(msg, style: const TextStyle(fontSize: 12, color: _partyRed)),
      ),
    );
  }

  /// Kotlin buildQuickActionRows(): har row mein [cols] card (2 / 3 / 4).
  Widget _grid(List<_Action> actions, int cols, AppPalette p, {double extent = 146}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: extent,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) => _actionCard(actions[i], p),
    );
  }

  /// Bakery Control tile: rang wala icon (gol chokor), naam, chhoti tafseel, gold teer.
  Widget _actionCard(_Action a, AppPalette p) {
    final comingSoon = a.open == null && a.onTap == null;
    return Material(
      color: p.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: p.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        onTap: () => _run(a),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: a.bg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: a.fg.withValues(alpha: 0.18)),
                ),
                child: Icon(a.icon, size: 21, color: a.fg),
              ),
              const Spacer(),
              if (a.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _partyRed, borderRadius: BorderRadius.circular(10)),
                  child: Text('${a.badge}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              else
                Icon(Icons.arrow_outward, size: 16, color: p.teal.withValues(alpha: 0.8)),
            ]),
            const Spacer(),
            Text(
              Loc.t(a.en, a.ur).replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: comingSoon ? p.textMuted : p.textDark),
            ),
            const SizedBox(height: 3),
            Text(
              Loc.t(a.subEn, a.subUr),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Kotlin askPasswordForSwitch() ka dialog. Apna controller khud sambhalta hai (dialog band hone par dispose).
class _PasswordDialog extends StatefulWidget {
  final String name;
  const _PasswordDialog({required this.name});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(Loc.t('Verify Password', 'پاس ورڈ کی تصدیق')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        obscureText: _obscure,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: InputDecoration(
          hintText: Loc.t("${widget.name}'s password", '${widget.name} کا پاس ورڈ'),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(Loc.t('Cancel', 'منسوخ کریں'))),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: Text(Loc.t('Switch', 'سوئچ کریں'))),
      ],
    );
  }
}
