import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../screens/about_screen.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import '../widgets/bakery_premium.dart';
import '../widgets/hanna_bakery_logo.dart';
import 'license_service.dart';

/// Haalat ka rang, icon, sarkhi aur tafseel (License screen, Settings panel aur yaad dihani — sab ek jagah se).
(Color, IconData, String, String) licenseLook(LicenseStatus s) {
  final p = ThemeManager.palette;
  final f = DateFormat('d MMM yyyy');
  switch (s.state) {
    case LicenseState.active:
      final info = s.info!;
      if (info.lifetime) {
        return (p.flatTealFg, Icons.verified, Loc.t('Licensed', 'لائسنس یافتہ'), Loc.t('Lifetime license', 'تاحیات لائسنس'));
      }
      if (s.warn) {
        return (
          p.amber,
          Icons.schedule,
          Loc.t('License ends in ${s.daysLeft} days', 'لائسنس ${s.daysLeft} دن میں ختم'),
          Loc.t('Renew before ${f.format(info.expiry!)} to keep working', '${f.format(info.expiry!)} سے پہلے تجدید کریں'),
        );
      }
      return (
        p.flatTealFg,
        Icons.verified,
        Loc.t('Licensed', 'لائسنس یافتہ'),
        Loc.t('${info.plan.toUpperCase()} · valid till ${f.format(info.expiry!)}', '${info.plan.toUpperCase()} · ${f.format(info.expiry!)} تک'),
      );
    case LicenseState.trial:
      return (
        p.blue,
        Icons.hourglass_bottom,
        Loc.t('Free trial · ${s.daysLeft} days left', 'مفت ٹرائل · ${s.daysLeft} دن باقی'),
        Loc.t('Activate a license to keep using ${AppInfo.appName}', 'استعمال جاری رکھنے کے لیے لائسنس لگائیں'),
      );
    case LicenseState.expired:
      return (
        p.red,
        Icons.lock_outline,
        Loc.t('License expired', 'لائسنس ختم'),
        Loc.t('Your data is safe. Enter a new license key to continue.', 'آپ کا ڈیٹا محفوظ ہے۔ جاری رکھنے کے لیے نئی لائسنس کی ڈالیں۔'),
      );
    case LicenseState.trialOver:
      return (
        p.red,
        Icons.lock_outline,
        Loc.t('Free trial ended', 'مفت ٹرائل ختم'),
        Loc.t('Your data is safe. Enter a license key to continue.', 'آپ کا ڈیٹا محفوظ ہے۔ جاری رکھنے کے لیے لائسنس کی ڈالیں۔'),
      );
    case LicenseState.clockTampered:
      return (
        p.red,
        Icons.event_busy,
        Loc.t('Phone date is wrong', 'فون کی تاریخ غلط ہے'),
        Loc.t('Set the correct date & time (automatic), then tap "Check again".',
            'درست تاریخ اور وقت (خودکار) لگائیں، پھر "دوبارہ چیک" دبائیں۔'),
      );
  }
}

/// License: haalat, Device ID, key lagana — Hanna Fitness jaisa premium.
///
/// [gate] = true: trial / license khatam — yahi app ki home screen hai (wapas nahi ja sakte). Activate hote hi
/// [LicenseService.notifier] badalta hai aur MaterialApp poori app dobara bana deta hai (Login / Dashboard).
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key, this.gate = false});
  final bool gate;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _key = TextEditingController();
  String _device = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LicenseService.deviceId();
    if (!widget.gate) await LicenseService.check();
    if (mounted) setState(() => _device = id);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isNotEmpty) setState(() => _key.text = t);
  }

  Future<void> _activate() async {
    if (_busy) return;
    if (_key.text.trim().isEmpty) {
      setState(() => _error = Loc.t('Paste the license key first', 'پہلے لائسنس کی پیسٹ کریں'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await LicenseService.activate(_key.text);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(Loc.t('License activated ✓', 'لائسنس لگ گیا ✓'));
      if (!widget.gate && s.allowed) {
        _key.clear();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _request() async {
    final msg = 'Assalam o Alaikum, Hanna Solutions!\n'
        '${AppInfo.appName} ka license chahiye.\n'
        'Device ID: $_device\n'
        'Shop name: ';
    final uri = Uri.parse('https://wa.me/${AppInfo.supportWhatsAppIntl}?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast(Loc.t('WhatsApp did not open', 'واٹس ایپ نہیں کھلا'));
    }
  }

  BoxDecoration _card(AppPalette p) => BoxDecoration(
        color: p.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      );

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return PopScope(
      canPop: !widget.gate,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: widget.gate
            ? null
            : AppBar(
                backgroundColor: p.navy,
                foregroundColor: ThemeManager.cream,
                title: Text(Loc.t('License', 'لائسنس')),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ValueListenableBuilder<LicenseStatus>(
                valueListenable: LicenseService.notifier,
                builder: (context, s, _) {
                  final (color, icon, title, sub) = licenseLook(s);
                  final info = s.info;
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
                    if (widget.gate) ...[
                      const SizedBox(height: 8),
                      const Center(child: HannaBakeryLogo(size: 84, glow: true)),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(AppInfo.appName.toUpperCase(),
                            style: TextStyle(color: p.textDark, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(Loc.t('EXECUTIVE BAKERY POINT OF SALE', 'ایگزیکٹو بیکری پوائنٹ آف سیل'),
                            style: TextStyle(color: p.teal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
                      ),
                      const SizedBox(height: 18),
                    ],
                    // Haalat
                    BakeryHero(
                      watermark: Icons.verified_user,
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: 0.5)),
                          ),
                          child: Icon(icon, color: color, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title,
                                style: const TextStyle(color: ThemeManager.cream, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(sub, style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.72), fontSize: 13)),
                            if (info != null && info.shop.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(Loc.t('Licensed to: ${info.shop}', 'لائسنس: ${info.shop}'),
                                  style: const TextStyle(color: ThemeManager.gold, fontWeight: FontWeight.w800)),
                            ],
                          ]),
                        ),
                      ]),
                    ),
                    if (s.state == LicenseState.clockTampered) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => LicenseService.check(),
                        icon: const Icon(Icons.refresh),
                        label: Text(Loc.t('I fixed the date — check again', 'تاریخ درست کر دی — دوبارہ چیک کریں')),
                      ),
                    ],
                    // Device ID
                    PremiumSection(Loc.t('YOUR DEVICE ID', 'آپ کی ڈیوائس آئی ڈی')),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _card(p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SelectableText(
                          _device.isEmpty ? '…' : _device,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: p.textDark, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2.5, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Loc.t('Send this ID to Hanna Solutions to get your license key.',
                              'لائسنس کی لینے کے لیے یہ آئی ڈی حنا سلوشنز کو بھیجیں۔'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textMuted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _device.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(ClipboardData(text: _device));
                                      _toast(Loc.t('Device ID copied', 'ڈیوائس آئی ڈی کاپی ہو گئی'));
                                    },
                              icon: Icon(Icons.copy, color: p.teal),
                              label: Text(Loc.t('Copy', 'کاپی')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _device.isEmpty ? null : _request,
                              icon: const Icon(Icons.chat),
                              label: Text(Loc.t('Request on WhatsApp', 'واٹس ایپ پر منگوائیں')),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    // Key
                    PremiumSection(Loc.t('ENTER LICENSE KEY', 'لائسنس کی ڈالیں')),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _card(p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _key,
                          minLines: 3,
                          maxLines: 5,
                          style: TextStyle(color: p.textDark, fontFamily: 'monospace', fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: Loc.t('Paste key (starts with HBK1.)', 'کی پیسٹ کریں (HBK1. سے شروع)'),
                            filled: true,
                            fillColor: p.fieldFill,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: p.red, fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _paste,
                              icon: Icon(Icons.content_paste, color: p.teal),
                              label: Text(Loc.t('Paste', 'پیسٹ')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                              onPressed: _busy ? null : _activate,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.onGold))
                                  : const Icon(Icons.vpn_key),
                              label: Text(Loc.t('ACTIVATE', 'لائسنس لگائیں')),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text('${AppInfo.business}  ·  ${AppInfo.supportPhone}  ·  ${AppInfo.supportEmail}',
                          textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 12)),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings mein License + About ki premium patti (Fitness jaisi): haalat ka rang + Device ID, aur logo wali About.
class LicenseAboutPanel extends StatefulWidget {
  const LicenseAboutPanel({super.key});

  @override
  State<LicenseAboutPanel> createState() => _LicenseAboutPanelState();
}

class _LicenseAboutPanelState extends State<LicenseAboutPanel> {
  String _device = '';

  @override
  void initState() {
    super.initState();
    LicenseService.deviceId().then((id) {
      if (mounted) setState(() => _device = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return ValueListenableBuilder<LicenseStatus>(
      valueListenable: LicenseService.notifier,
      builder: (context, s, _) {
        final (color, icon, title, sub) = licenseLook(s);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PremiumSection(Loc.t('LICENSE & ABOUT', 'لائسنس اور تعارف')),
          Container(
            decoration: BoxDecoration(
              color: p.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LicenseScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: p.textDark)),
                        const SizedBox(height: 2),
                        Text(sub, style: TextStyle(fontSize: 12.5, color: p.textMuted)),
                        if (_device.isNotEmpty)
                          Text('${Loc.t('Device ID', 'ڈیوائس آئی ڈی')}: $_device',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.teal)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: p.textMuted),
                  ]),
                ),
              ),
              Divider(height: 1, color: p.border),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const HannaBakeryLogo(size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppInfo.appName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: p.textDark)),
                        const SizedBox(height: 2),
                        Text(
                            'v1.0${AppInfo.build.isEmpty ? '' : ' (build ${AppInfo.build})'}  ·  '
                            '${Loc.t('Support, privacy, delete my data', 'سپورٹ، پرائیویسی، ڈیٹا ختم')}',
                            style: TextStyle(fontSize: 12.5, color: p.textMuted)),
                        Text('${AppInfo.business} · ${AppInfo.developer}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.teal)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: p.textMuted),
                  ]),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Dashboard: license / trial 7 din ya kam reh jaye to din mein ek dafa yaad dihani.
DateTime? _lastWarnShown;

Future<void> maybeShowLicenseWarning(BuildContext context) async {
  final s = LicenseService.current;
  if (!s.warn) return;
  final now = DateTime.now();
  final last = _lastWarnShown;
  if (last != null && last.year == now.year && last.month == now.month && last.day == now.day) return;
  _lastWarnShown = now;
  final (color, icon, title, sub) = licenseLook(s);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: color),
      title: Text(title),
      content: Text('$sub\n${Loc.t('Contact', 'رابطہ')}: ${AppInfo.supportPhone}'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(Loc.t('Later', 'بعد میں'))),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LicenseScreen()));
          },
          child: Text(Loc.t('Open License', 'لائسنس کھولیں')),
        ),
      ],
    ),
  );
}
