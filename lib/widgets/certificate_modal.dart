import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'club_logo.dart';

/// Certificate overlay. Note: in the source design the "Download PDF"
/// button has no handler wired to it — reproduced as a no-op here too.
class CertificateModal extends StatelessWidget {
  final AppState state;
  const CertificateModal({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cert = state.cert!;
    return Positioned.fill(
      child: Container(
        color: const Color(0xB80A1223),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFFFFDF7),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: RCColors.blue, width: 3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClubLogoImage(state: state, height: 34),
                          const SizedBox(height: 10),
                          const Text('CERTIFICATE',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 3,
                                  color: RCColors.amber,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(cert.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: RCColors.blue,
                                  height: 1.3)),
                          const SizedBox(height: 4),
                          const Text('is proudly awarded to',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF4A5670))),
                          const SizedBox(height: 4),
                          const Text('Rtn. Sarah Namuli',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: RCColors.textDark,
                                  fontStyle: FontStyle.italic)),
                          const SizedBox(height: 4),
                          Text(cert.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: RCColors.textMuted,
                                  height: 1.5)),
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SignatureLine(label: 'Club President'),
                              _SignatureLine(label: 'Club Secretary'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: RCColors.goldOnLight, width: 1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                        top: 0, left: 0, child: _CornerTriangles()),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: const _CornerTriangles(),
                      ),
                    ),
                    const Positioned(top: 10, right: 10, child: _AwardBadge()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.closeCert,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RCColors.textDark,
                          side: const BorderSide(color: Color(0xFFD4DAE5)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: RCColors.blue,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Download PDF',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A nested pair of corner triangles (blue behind, gold in front and
/// offset toward the center) — the layered wedge accent from the source
/// design. Drawn pointing at the top-left; rotate 180° for bottom-right.
class _CornerTriangles extends StatelessWidget {
  const _CornerTriangles();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          _Triangle(size: 92, color: RCColors.blue),
          Positioned(
            left: 16,
            top: 16,
            child: _Triangle(size: 58, color: RCColors.goldOnLight),
          ),
        ],
      ),
    );
  }
}

class _Triangle extends StatelessWidget {
  final double size;
  final Color color;
  const _Triangle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TopLeftTriangleClipper(),
      child: Container(width: size, height: size, color: color),
    );
  }
}

class _TopLeftTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// The gold "seal" badge with two ribbon tails hanging below it, echoing
/// the award medallion in the source design.
class _AwardBadge extends StatelessWidget {
  const _AwardBadge();

  @override
  Widget build(BuildContext context) {
    final gold = RCColors.goldOnLight;
    return SizedBox(
      width: 40,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 22,
            left: 4,
            child: Transform.rotate(
              angle: -0.35,
              child: _RibbonTail(color: gold),
            ),
          ),
          Positioned(
            top: 22,
            right: 4,
            child: Transform.rotate(
              angle: 0.35,
              child: _RibbonTail(color: gold),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.star_rounded,
                color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RibbonTail extends StatelessWidget {
  final Color color;
  const _RibbonTail({required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonTailClipper(),
      child: Container(width: 10, height: 22, color: color),
    );
  }
}

class _RibbonTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height - 6)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _SignatureLine extends StatelessWidget {
  final String label;
  const _SignatureLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF9AA6BA)))),
      child: Text(label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF4A5670))),
    );
  }
}
