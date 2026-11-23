import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import 'license_service.dart';

/// License: status, Device ID (copy / WhatsApp developer ko), key paste karke activate.
///
/// [gate] = true: trial / license khatam — yahi app ki home screen hai (aage nahi ja sakte). Activate hote hi
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await LicenseService.activate(_key.text);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(Loc.t('License activated', 'لائسنس ایکٹیو ہو گیا'));
      if (!widget.gate && s.allowed) _key.clear();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _whatsApp() async {
    final msg = 'Assalam o Alaikum, mujhe ${AppInfo.appName} ka license chahiye.\n'
        'Device ID: $_device\nShop name: ';
    final uri = Uri.parse('https://wa.me/${AppInfo.supportWhatsAppIntl}?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast(Loc.t('WhatsApp did not open', 'واٹس ایپ نہیں کھلا'));
    }
  }

  (String, String, Color) _headline(LicenseStatus s, AppPalette p) {
    final f = DateFormat('d MMM yyyy');
    switch (s.state) {
      case LicenseState.active:
        final info = s.info!;
        return (
          Loc.t('Licensed', 'لائسنس یافتہ'),
          info.lifetime
              ? Loc.t('Lifetime license', 'لائف ٹائم لائسنس')
              : '${Loc.t('Valid till', 'تک درست')} ${f.format(info.expiry!)}  (${s.daysLeft} ${Loc.t('days left', 'دن باقی')})',
          p.flatTealFg,
        );
      case LicenseState.trial:
        return (
          Loc.t('Free trial', 'مفت ٹرائل'),
          '${s.daysLeft} ${Loc.t('days left — activate to keep using', 'دن باقی — استعمال جاری رکھنے کے لیے ایکٹیویٹ کریں')}',
          p.flatAmberFg,
        );
      case LicenseState.expired:
        return (
          Loc.t('License expired', 'لائسنس ختم ہو گیا'),
          '${Loc.t('Expired on', 'ختم ہوا')} ${s.info?.expiry == null ? '' : f.format(s.info!.expiry!)}. '
              '${Loc.t('Your data is safe. Renew to continue.', 'آپ کا ڈیٹا محفوظ ہے۔ جاری رکھنے کے لیے تجدید کریں۔')}',
          p.red,
        );
      case LicenseState.trialOver:
        return (
          Loc.t('Trial finished', 'ٹرائل ختم'),
          Loc.t('Your data is safe. Get a license key to continue.', 'آپ کا ڈیٹا محفوظ ہے۔ جاری رکھنے کے لیے لائسنس کی لیں۔'),
          p.red,
        );
      case LicenseState.clockTampered:
        return (
          Loc.t('Phone date/time is wrong', 'فون کی تاریخ / وقت غلط ہے'),
          Loc.t('Set the correct date & time (automatic) and reopen the app.',
              'درست تاریخ اور وقت (خودکار) لگائیں اور ایپ دوبارہ کھولیں۔'),
          p.red,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return ValueListenableBuilder<LicenseStatus>(
      valueListenable: LicenseService.notifier,
      builder: (context, s, _) {
        final (title, sub, color) = _headline(s, p);
        final info = s.info;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            automaticallyImplyLeading: !widget.gate,
            backgroundColor: p.navy,
            foregroundColor: Colors.white,
            title: Text('${AppInfo.appName} — ${Loc.t('License', 'لائسنس')}'),
          ),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Row(children: [
                Icon(s.allowed ? Icons.verified_user : Icons.lock_outline, color: color, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(sub, style: TextStyle(color: p.textDark, fontSize: 13.5)),
                    if (info != null && info.shop.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${Loc.t('Shop', 'دکان')}: ${info.shop}  •  ${info.plan.toUpperCase()}',
                          style: TextStyle(color: p.textMuted, fontSize: 12.5)),
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text(Loc.t('YOUR DEVICE ID', 'آپ کی ڈیوائس آئی ڈی'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: p.cardWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
              child: Row(children: [
                Expanded(
                  child: SelectableText(
                    _device.isEmpty ? '…' : _device,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: p.textDark, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: Loc.t('Copy', 'کاپی'),
                  icon: const Icon(Icons.copy),
                  onPressed: _device.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: _device));
                          _toast(Loc.t('Device ID copied', 'ڈیوائس آئی ڈی کاپی ہو گئی'));
                        },
                ),
              ]),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _device.isEmpty ? null : _whatsApp,
              icon: const Icon(Icons.chat_outlined),
              label: Text(Loc.t('Send Device ID on WhatsApp (${AppInfo.supportPhone})', 'ڈیوائس آئی ڈی واٹس ایپ پر بھیجیں (${AppInfo.supportPhone})')),
            ),
            const SizedBox(height: 22),
            Text(Loc.t('LICENSE KEY', 'لائسنس کی'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: p.textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _key,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'HBK1.xxxxxxxx.xxxxxxxx',
                errorText: _error,
                errorMaxLines: 3,
                filled: true,
                fillColor: p.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(tooltip: Loc.t('Paste', 'پیسٹ'), icon: const Icon(Icons.content_paste), onPressed: _paste),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : _activate,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.vpn_key_outlined),
              label: Text(Loc.t('ACTIVATE', 'ایکٹیویٹ کریں')),
            ),
            if (s.state == LicenseState.clockTampered) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => LicenseService.check(),
                icon: const Icon(Icons.refresh),
                label: Text(Loc.t('I fixed the date — check again', 'تاریخ درست کر دی — دوبارہ چیک کریں')),
              ),
            ],
            const SizedBox(height: 26),
            Text(
              '${AppInfo.business}  •  ${AppInfo.developer}  •  ${AppInfo.supportPhone}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 12),
            ),
          ]),
        );
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
  final trial = s.state == LicenseState.trial;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.info_outline),
      title: Text(trial ? Loc.t('Trial ending soon', 'ٹرائل ختم ہونے والا ہے') : Loc.t('License ending soon', 'لائسنس ختم ہونے والا ہے')),
      content: Text('${s.daysLeft} ${Loc.t('days left. Contact', 'دن باقی۔ رابطہ کریں')} ${AppInfo.supportPhone}'),
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
