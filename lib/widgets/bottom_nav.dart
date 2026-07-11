import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// Persistent bottom nav — in the source design this bar sits outside every
/// `sc-if` screen block, so it renders on top of *every* screen including
/// Splash and Today, not just the four primary tabs. Reproduced as-is.
class BottomNav extends StatelessWidget {
  final AppState state;
  const BottomNav({super.key, required this.state});

  Color _navColor(String t) =>
      state.tab == t ? RCColors.blue : const Color(0xFF8B96A8);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 70 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: RCColors.divider2)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _NavButton(
                  icon: '⌂',
                  label: 'Home',
                  color: _navColor('home'),
                  onTap: state.goHome)),
          Expanded(
              child: _NavButton(
                  icon: '▦',
                  label: 'Events',
                  color: _navColor('events'),
                  onTap: state.goEvents)),
          Expanded(
            child: Center(
              // The design's `margin-top:-24px` on a centered 52px button nets
              // out to the circle peeking ~3px above the bar, i.e. a 12px lift
              // from center — not a full 24px translate.
              child: Transform.translate(
                offset: const Offset(0, -12),
                child: Material(
                  color: RCColors.scanLauncherBg,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: state.goScan,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      child: Text(
                        '⌗',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: RCColors.scanLauncherIcon),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _NavButton(
                icon: '✓',
                label: 'Attendance',
                color: _navColor('attendance'),
                onTap: state.goAttendance),
          ),
          Expanded(
            child: _NavButton(
                icon: '◉',
                label: 'Members',
                color: _navColor('members'),
                onTap: state.goMembers),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: 22, height: 1, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
