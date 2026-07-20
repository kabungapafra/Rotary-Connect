import 'package:flutter/material.dart';

/// Sweeps a moving highlight across whatever [child] contains — wrap a
/// column of [RCSkeletonBox]es in one shimmer instead of animating each
/// box separately, so a whole loading screen shares a single ticker.
class RCShimmer extends StatefulWidget {
  final Widget child;
  const RCShimmer({super.key, required this.child});

  @override
  State<RCShimmer> createState() => _RCShimmerState();
}

class _RCShimmerState extends State<RCShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1 + _controller.value * 3, 0),
          end: Alignment(_controller.value * 3, 0),
          stops: const [0.35, 0.5, 0.65],
          colors: const [
            Color(0x00FFFFFF),
            Color(0x66FFFFFF),
            Color(0x00FFFFFF),
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A solid placeholder block standing in for a line of text, an avatar, or
/// an image tile while real content loads. Combine several under one
/// [RCShimmer] to build a screen's skeleton layout.
class RCSkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;
  final Color color;
  const RCSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.color = const Color(0xFFE7EBF3),
  });

  /// Circular variant, for avatar-shaped placeholders.
  const RCSkeletonBox.circle({
    super.key,
    required double size,
    this.color = const Color(0xFFE7EBF3),
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration:
            BoxDecoration(color: color, borderRadius: borderRadius),
      );
}
