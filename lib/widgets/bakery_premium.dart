import 'package:flutter/material.dart';

import '../theme/theme_manager.dart';

/// Hanna Bakery POS — executive UI parts (dashboard aur bakery screens).
/// Espresso -> cocoa gradient, champagne gold hairlines, cream text. Hanna Fitness jaisa premium,
/// lekin bakery ka apna "patisserie" andaaz (watermark, gold pills, warm KPI tiles).

/// Hero panel: gradient + halka gold border + bara bakery watermark.
class BakeryHero extends StatelessWidget {
  const BakeryHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.watermark = Icons.bakery_dining,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final IconData watermark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThemeManager.heroTop, ThemeManager.heroBottom],
        ),
        border: Border.all(color: ThemeManager.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(children: [
          PositionedDirectional(
            end: -28,
            bottom: -34,
            child: Icon(watermark, size: 190, color: ThemeManager.gold.withValues(alpha: 0.07)),
          ),
          // Upar patli gold chamak
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  ThemeManager.gold.withValues(alpha: 0),
                  ThemeManager.gold.withValues(alpha: 0.8),
                  ThemeManager.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ]),
      ),
    );
  }
}

/// Hero ke andar gol "glass" button (settings / sync / switch user).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.tooltip, this.onTap, this.dot = false, this.busy = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool dot;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(side: BorderSide(color: ThemeManager.gold.withValues(alpha: 0.25))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(alignment: Alignment.center, children: [
              busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.gold))
                  : Icon(icon, size: 19, color: ThemeManager.cream),
              if (dot && !busy)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: Color(0xFFF07A70), shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Gold "pill" CTA (hero quick actions).
class GoldPill extends StatelessWidget {
  const GoldPill({super.key, required this.icon, required this.label, required this.onTap, this.outlined = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? ThemeManager.gold : ThemeManager.onGold;
    return Material(
      color: outlined ? Colors.white.withValues(alpha: 0.06) : ThemeManager.gold,
      shape: StadiumBorder(side: outlined ? BorderSide(color: ThemeManager.gold.withValues(alpha: 0.6)) : BorderSide.none),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.2)),
          ]),
        ),
      ),
    );
  }
}

/// Hero ka bara number + chhota label.
class HeroFigure extends StatelessWidget {
  const HeroFigure({super.key, required this.value, required this.label, this.accent = false});
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(value,
            style: TextStyle(
              color: accent ? ThemeManager.gold : ThemeManager.cream,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            )),
      ),
      const SizedBox(height: 2),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ThemeManager.cream.withValues(alpha: 0.6), fontSize: 11.5, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Section heading: gold patti + spaced caps + optional action.
class PremiumSection extends StatelessWidget {
  const PremiumSection(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 22, 2, 12),
      child: Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: p.teal, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(fontSize: 12.5, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: p.textDark)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// KPI tile: rang wala icon, bara amount, label, chhota hint.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.soft,
    this.hint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color soft;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = ThemeManager.palette;
    return Material(
      color: p.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              if (onTap != null) Icon(Icons.arrow_outward, size: 16, color: p.textMuted),
            ]),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.textDark)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textMuted)),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ]),
        ),
      ),
    );
  }
}
