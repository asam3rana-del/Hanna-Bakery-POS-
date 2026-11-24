import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../theme/theme_manager.dart';
import '../utils/loc.dart';
import '../widgets/bakery_premium.dart';
import '../widgets/hanna_bakery_logo.dart';

/// About / Privacy / Support — Hanna Fitness jaisa premium (logo hero, gold patti, saaf tiles).
/// Play Store policy: privacy policy ka link aur data delete karwane ka tareeqa app ke andar.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Loc.t('Could not open: $uri', 'نہیں کھل سکا: $uri'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    final version = 'v1.0${AppInfo.build.isEmpty ? '' : '  ·  build ${AppInfo.build}'}';
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.navy,
        foregroundColor: ThemeManager.cream,
        title: Text(Loc.t('About', 'ایپ کے بارے میں')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            BakeryHero(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              child: Column(children: [
                const HannaBakeryLogo(size: 92, glow: true),
                const SizedBox(height: 16),
                Text(AppInfo.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: ThemeManager.cream, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const SizedBox(height: 6),
                Text(Loc.t('EXECUTIVE BAKERY POINT OF SALE', 'ایگزیکٹو بیکری پوائنٹ آف سیل'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: ThemeManager.gold, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThemeManager.gold.withValues(alpha: 0.35)),
                  ),
                  child: Text(version,
                      style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 14),
                Text('${AppInfo.business}  ·  ${AppInfo.developer}',
                    style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.65), fontSize: 12.5)),
                Text(AppInfo.address,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.45), fontSize: 11.5)),
              ]),
            ),
            PremiumSection(Loc.t('SUPPORT', 'سپورٹ')),
            _Group(children: [
              _Tile(
                icon: Icons.chat_outlined,
                color: p.flatTealFg,
                soft: p.flatTealBg,
                title: Loc.t('WhatsApp support', 'واٹس ایپ سپورٹ'),
                sub: AppInfo.supportPhone,
                onTap: () => _open(context,
                    Uri.parse('https://wa.me/${AppInfo.supportWhatsAppIntl}?text=${Uri.encodeComponent('${AppInfo.appName} support')}')),
              ),
              _Tile(
                icon: Icons.call_outlined,
                color: p.flatBlueFg,
                soft: p.flatBlueBg,
                title: Loc.t('Call support', 'سپورٹ کو کال'),
                sub: AppInfo.supportPhone,
                onTap: () => _open(context, Uri(scheme: 'tel', path: AppInfo.supportPhone)),
              ),
              _Tile(
                icon: Icons.email_outlined,
                color: p.flatAmberFg,
                soft: p.flatAmberBg,
                title: Loc.t('Email support', 'ای میل سپورٹ'),
                sub: AppInfo.supportEmail,
                onTap: () => _open(context,
                    Uri(scheme: 'mailto', path: AppInfo.supportEmail, query: 'subject=${AppInfo.appName} support')),
              ),
            ]),
            PremiumSection(Loc.t('PRIVACY & DATA', 'پرائیویسی اور ڈیٹا')),
            _Group(children: [
              _Tile(
                icon: Icons.privacy_tip_outlined,
                color: p.flatPurpleFg,
                soft: p.flatPurpleBg,
                title: Loc.t('Privacy Policy', 'پرائیویسی پالیسی'),
                sub: Loc.t('How your shop data is kept', 'آپ کی دکان کا ڈیٹا کیسے محفوظ رہتا ہے'),
                onTap: () => _open(context, Uri.parse(AppInfo.privacyPolicyUrl)),
              ),
              _Tile(
                icon: Icons.delete_forever_outlined,
                color: p.red,
                soft: p.flatCoralBg,
                title: Loc.t('Delete my data', 'میرا ڈیٹا ختم کریں'),
                sub: Loc.t(
                  'Records can be deleted inside the app. For cloud data or a staff account, message us from the '
                      "owner's number with your shop name — done within 30 days.",
                  'ریکارڈ ایپ کے اندر حذف ہو سکتے ہیں۔ کلاؤڈ ڈیٹا یا اسٹاف اکاؤنٹ کے لیے مالک کے نمبر سے دکان کے نام '
                      'کے ساتھ رابطہ کریں — 30 دن کے اندر ختم۔',
                ),
                onTap: () => _open(context,
                    Uri(scheme: 'mailto', path: AppInfo.supportEmail, query: 'subject=${AppInfo.appName} - delete my data')),
              ),
            ]),
            PremiumSection(Loc.t('HANNA SOFTWARE SERIES', 'حنا سافٹ ویئر سیریز')),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in const ['Hanna POS', 'Hanna Pharmacy', 'Hanna Installment', 'Hanna Fitness', 'Hanna Bakery'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: n == 'Hanna Bakery' ? p.teal.withValues(alpha: 0.16) : p.fieldFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: n == 'Hanna Bakery' ? p.teal : p.border),
                    ),
                    child: Text(n,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: n == 'Hanna Bakery' ? FontWeight.w900 : FontWeight.w600,
                            color: n == 'Hanna Bakery' ? p.navyInk : p.textMuted)),
                  ),
              ]),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text('${AppInfo.appId}  ·  © ${DateTime.now().year} ${AppInfo.business}',
                  style: TextStyle(color: p.textMuted, fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 68, color: p.border),
          children[i],
        ],
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.textDark)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 12.5, color: p.textMuted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.textMuted),
        ]),
      ),
    );
  }
}
