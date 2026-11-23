import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_manager.dart';

/// Screen header — espresso gradient + champagne gold (Hanna Bakery executive look), with
/// title/subtitle on the left and a "View List" pill on the right.
class PremiumHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final String? actionEmoji;
  final VoidCallback? onActionTap;

  /// Action pill se pehle ke chhote gol icon buttons (Kotlin buildHeader: Export Rate List icon).
  final List<PremiumHeaderIcon> iconActions;

  /// Optional: title se pehle (jaise back arrow) aur sab se aakhir mein (jaise 3-dot menu) ka widget.
  final Widget? leading;
  final Widget? trailing;

  const PremiumHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionEmoji,
    this.onActionTap,
    this.iconActions = const [],
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Hanna premium: navy gradient, gold patti, halke chamakte daire, naram gehri shadow.
    // Size / padding pehle jaisa — screens ka layout nahi badla.
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThemeManager.heroTop, ThemeManager.heroBottom],
        ),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(children: [
        // Sajawati daire (touch nahi lete).
        PositionedDirectional(
          end: -40,
          top: -50,
          child: IgnorePointer(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
        ),
        PositionedDirectional(
          end: 60,
          bottom: -60,
          child: IgnorePointer(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.gold.withValues(alpha: 0.07)),
            ),
          ),
        ),
        Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          // Hanna gold patti.
          Container(
            width: 4,
            height: 34,
            margin: const EdgeInsetsDirectional.only(end: 12),
            decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: ThemeManager.cream, fontSize: 18.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.gold.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          for (final a in iconActions) ...[
            Tooltip(
              message: a.tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: a.onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeManager.palette.headerBadgeOverlay,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(a.icon, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (actionLabel != null)
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: ThemeManager.palette.headerBadgeOverlay,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionEmoji != null) ...[
                      Text(actionEmoji!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      actionLabel!,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
        ),
      ]),
    );
  }
}

/// Header ka chhota gol icon button (tooltip = Kotlin contentDescription).
class PremiumHeaderIcon {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const PremiumHeaderIcon({required this.icon, required this.tooltip, required this.onTap});
}
