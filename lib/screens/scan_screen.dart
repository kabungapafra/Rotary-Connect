import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';

class ScanScreen extends StatelessWidget {
  final AppState state;
  const ScanScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final scanning = state.scanStep == 'idle';
    return Container(
      color: RCColors.scanBg,
      child: Stack(
        children: [
          // The whole screen shows the live camera feed while scanning —
          // not just a small boxed preview — like a normal QR scanner app.
          if (scanning) Positioned.fill(child: _CameraFeed(state: state)),
          if (scanning)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 18 + MediaQuery.of(context).padding.top, 20, 8),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meeting check-in',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Scan the club QR code displayed at the venue',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                        child: _ScanTab(
                            label: 'Member',
                            active: state.scanMode == 'member',
                            onTap: state.pickMember)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ScanTab(
                            label: 'Guest',
                            active: state.scanMode == 'guest',
                            onTap: state.pickGuest)),
                  ],
                ),
              ),
              Expanded(child: _buildStep(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (state.scanStep) {
      case 'success':
        return _ScanSuccess(state: state);
      case 'guestForm':
        return _GuestForm(state: state);
      case 'guestDone':
        return _GuestDone(state: state);
      case 'idle':
      default:
        return _ScanIdle(state: state);
    }
  }
}

/// Full-screen live camera feed — the whole scan screen shows what the
/// camera captures, with the corner-bracket frame floating on top as a
/// target guide, matching a normal QR scanner app.
class _CameraFeed extends StatefulWidget {
  final AppState state;
  const _CameraFeed({required this.state});

  @override
  State<_CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<_CameraFeed> {
  final MobileScannerController _camera = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    // A real QR read completes check-in the same way "Simulate scan" does —
    // there's no backend to validate the club's code against, so any
    // successfully decoded QR is treated as a valid scan.
    if (_handled || capture.barcodes.isEmpty) return;
    _handled = true;
    widget.state.simulateScan();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RCColors.scanBg,
      child: MobileScanner(
        controller: _camera,
        fit: BoxFit.cover,
        onDetect: _onDetect,
        errorBuilder: (context, error) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Camera unavailable — use Simulate scan below',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: RCColors.scanMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ScanTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? RCColors.gold : RCColors.scanCard,
        foregroundColor: active ? RCColors.blue : RCColors.scanMuted,
        side: BorderSide(color: active ? RCColors.gold : RCColors.scanBorder),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _ScanIdle extends StatefulWidget {
  final AppState state;
  const _ScanIdle({required this.state});

  @override
  State<_ScanIdle> createState() => _ScanIdleState();
}

class _ScanIdleState extends State<_ScanIdle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                children: [
                  ..._corners(),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final top = 230 * (0.08 + _controller.value * 0.80);
                      return Positioned(
                        top: top,
                        left: 230 * 0.08,
                        right: 230 * 0.08,
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            color: RCColors.gold,
                            boxShadow: [
                              BoxShadow(color: RCColors.gold, blurRadius: 12)
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.state.simulateScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.gold,
                foregroundColor: RCColors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Simulate scan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const s = 36.0;
    const t = 4.0;
    BoxDecoration deco(
        {bool top = false,
        bool bottom = false,
        bool left = false,
        bool right = false}) {
      return BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          bottom: bottom
              ? const BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          right: right
              ? const BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(20) : Radius.zero,
          topRight: top && right ? const Radius.circular(20) : Radius.zero,
          bottomLeft: bottom && left ? const Radius.circular(20) : Radius.zero,
          bottomRight:
              bottom && right ? const Radius.circular(20) : Radius.zero,
        ),
      );
    }

    return [
      Positioned(
          top: 0,
          left: 0,
          child: Container(
              width: s, height: s, decoration: deco(top: true, left: true))),
      Positioned(
          top: 0,
          right: 0,
          child: Container(
              width: s, height: s, decoration: deco(top: true, right: true))),
      Positioned(
          bottom: 0,
          left: 0,
          child: Container(
              width: s, height: s, decoration: deco(bottom: true, left: true))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Container(
              width: s,
              height: s,
              decoration: deco(bottom: true, right: true))),
    ];
  }
}

class _ScanSuccess extends StatelessWidget {
  final AppState state;
  const _ScanSuccess({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: RCColors.green, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('✓',
                  style: TextStyle(fontSize: 40, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            const Text('Attendance recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Weekly Fellowship Meeting · 8 Jul 2026, 6:02 PM',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Week streak now 8 — keep it up!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RCColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.goToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RCColors.gold,
                  foregroundColor: RCColors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("See who's here today",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.goAttendance,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View my attendance',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: state.resetScan,
              child: const Text('Scan again',
                  style: TextStyle(color: RCColors.scanMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestForm extends StatelessWidget {
  final AppState state;
  const _GuestForm({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Guest registration',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _ScanInput(
              hint: 'Full name',
              value: state.guestName,
              onChanged: state.setGuestName),
          const SizedBox(height: 12),
          _ScanInput(
              hint: 'Phone number',
              value: state.guestPhone,
              onChanged: state.setGuestPhone),
          const SizedBox(height: 12),
          _ScanInput(
              hint: 'Guest of (member name)',
              value: state.guestHost,
              onChanged: state.setGuestHost),
          const SizedBox(height: 4),
          const Text('Guest type',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in guestTypes)
                _GuestTypeChip(
                    label: t,
                    active: state.guestType == t,
                    onTap: () => state.setGuestType(t)),
            ],
          ),
          if (state.isVisitingRotarian) ...[
            const SizedBox(height: 12),
            _ScanInput(
              hint: 'Home club (e.g. Rotary Club of Naalya)',
              value: state.guestClub,
              onChanged: state.setGuestClub,
              accent: true,
            ),
          ],
          if (state.guestFormError) ...[
            const SizedBox(height: 12),
            const Text("Please enter the guest's full name.",
                style: TextStyle(color: Color(0xFFFF9D9D), fontSize: 12)),
          ],
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: state.submitGuest,
            style: ElevatedButton.styleFrom(
              backgroundColor: RCColors.gold,
              foregroundColor: RCColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Register & check in',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _ScanInput extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool accent;
  const _ScanInput(
      {required this.hint,
      required this.value,
      required this.onChanged,
      this.accent = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: RCColors.scanMuted),
        filled: true,
        fillColor: RCColors.scanCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: accent ? RCColors.gold : RCColors.scanBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: accent ? RCColors.gold : RCColors.scanBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: accent ? RCColors.gold : RCColors.scanBorder),
        ),
      ),
    );
  }
}

class _GuestTypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _GuestTypeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? RCColors.gold : RCColors.scanCard,
        foregroundColor: active ? RCColors.blue : RCColors.scanMuted,
        side: BorderSide(color: active ? RCColors.gold : RCColors.scanBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: const StadiumBorder(),
        elevation: 0,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _GuestDone extends StatelessWidget {
  final AppState state;
  const _GuestDone({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: RCColors.green, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('✓',
                  style: TextStyle(fontSize: 40, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Text('Welcome, ${state.guestNameShown}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                'Registered as ${state.guestTypeShown}${state.guestClubShown} · attendance recorded',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text(state.guestStreakLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: RCColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.goToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RCColors.gold,
                  foregroundColor: RCColors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("See who's here today",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.resetScan,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Register another guest',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
