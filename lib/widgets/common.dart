import 'package:flutter/material.dart';
import '../theme.dart';

/// White rounded card with the soft blue drop-shadow used throughout.
class RCCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const RCCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: RCColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
        borderRadius: BorderRadius.circular(14), onTap: onTap, child: card);
  }
}

/// Circular member avatar — the Rotary wheel mark on a brand-colored disc.
class RCAvatar extends StatelessWidget {
  final Color color;
  final double size;
  const RCAvatar({super.key, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: Image.asset('assets/images/rotary_wheel_spin.png',
            width: size * 0.62, height: size * 0.62),
      ),
    );
  }
}

/// One of the 3-across stat boxes (e.g. Attendance / Week streak / Certificates).
class RCStatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const RCStatBox(
      {super.key,
      required this.value,
      required this.label,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RCCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? RCColors.blue)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: RCColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// "Section title" + optional trailing link (e.g. "See all photos").
class RCSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const RCSectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: RCColors.textDark)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RCColors.blue)),
          ),
      ],
    );
  }
}

/// Blue header bar with an optional back (‹) button, used at the top of
/// most non-tab screens.
class RCHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const RCHeader({
    super.key,
    this.onBack,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: RCColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Padding(
            padding: padding,
            child: onBack == null
                ? child
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackButton(onTap: onBack!),
                      const SizedBox(width: 12),
                      Expanded(child: child),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Center(
              child: Text('‹',
                  style: TextStyle(color: Colors.white, fontSize: 16))),
        ),
      ),
    );
  }
}

/// Repeating diagonal-stripe placeholder used everywhere a real photo would
/// go, matching the design's `repeating-linear-gradient` placeholders.
class RCPhotoPlaceholder extends StatelessWidget {
  final String? label;
  final BorderRadiusGeometry borderRadius;
  final Alignment labelAlignment;
  const RCPhotoPlaceholder({
    super.key,
    this.label,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.labelAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: CustomPaint(
        painter: _StripePainter(),
        child: Container(
          alignment: labelAlignment,
          padding: const EdgeInsets.all(6),
          child: label == null
              ? null
              : Container(
                  padding: labelAlignment == Alignment.bottomLeft
                      ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
                      : EdgeInsets.zero,
                  decoration: labelAlignment == Alignment.bottomLeft
                      ? BoxDecoration(
                          color: Colors.white.withValues(alpha: .9),
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8)),
                        )
                      : null,
                  child: Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: labelAlignment == Alignment.bottomLeft
                        ? TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: RCColors.blue)
                        : const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: Color(0xFF5A6A85)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEEF2F9);
    canvas.drawRect(Offset.zero & size, bg);
    final stripe = Paint()..color = const Color(0xFFDDE5F2);
    const gap = 16.0;
    final diag = size.width + size.height;
    for (double x = -size.height; x < diag; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0),
          stripe..strokeWidth = 8);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
