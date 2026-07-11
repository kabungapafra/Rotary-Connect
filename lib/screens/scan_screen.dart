import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

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

class _CameraFeedState extends State<_CameraFeed> with WidgetsBindingObserver {
  final MobileScannerController _camera = MobileScannerController();
  bool _handled = false;
  String? _invalidMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // The camera is released whenever the app goes to the background (or the
  // OS takes it for another app) and does NOT come back by itself — without
  // this, returning to the scan screen shows the "camera unavailable"
  // error state until the app is killed and reopened.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _camera.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _camera.stop();
      default:
        break;
    }
  }

  /// Every printed club QR encodes {"t":"rc_club","id":<club id>} — the
  /// dashboard generates it (see admin_dashboard's ClubQrCode widget), so
  /// any other QR (a random poster, a different app's code) is rejected
  /// rather than silently treated as valid.
  int? _decodeClubId(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['t'] == 'rc_club' && data['id'] is int) {
        return data['id'] as int;
      }
    } catch (_) {
      // Not JSON, or not our shape — fall through to null.
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (widget.state.scanMode == 'member') {
      // A member checking in at their own club's meeting doesn't need the
      // QR to carry anything — their club comes from their login.
      _handled = true;
      widget.state.simulateScan();
      return;
    }
    final clubId = raw == null ? null : _decodeClubId(raw);
    if (clubId == null) {
      setState(
          () => _invalidMessage = "That's not a Rotary Connect club QR code");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _invalidMessage = null);
      });
      return;
    }
    _handled = true;
    widget.state.handleClubQrScanned(clubId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RCColors.scanBg,
      child: Stack(
        children: [
          MobileScanner(
            controller: _camera,
            fit: BoxFit.cover,
            onDetect: _onDetect,
            // Camera hardware start-up is a few hundred ms on most phones —
            // show a clear, branded "starting" state instead of a blank/
            // black frame so the screen never looks broken while it warms
            // up.
            placeholderBuilder: (context) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white70),
                  ),
                  SizedBox(height: 12),
                  Text('Starting camera…',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Camera unavailable — check your camera permission',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: RCColors.scanMuted),
                    ),
                    const SizedBox(height: 14),
                    PressableScale(
                      child: OutlinedButton(
                        onPressed: () => _camera.start(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Try again',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_invalidMessage != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 140,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _invalidMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ),
            ),
        ],
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
    return PressableScale(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? RCColors.gold : RCColors.scanCard,
          foregroundColor: active ? RCColors.blue : RCColors.scanMuted,
          side: BorderSide(color: active ? RCColors.gold : RCColors.scanBorder),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
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
                          decoration: BoxDecoration(
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
            if (widget.state.checkInLoading) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: RCColors.gold),
              ),
              const SizedBox(height: 10),
              const Text('Checking in…',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
            if (widget.state.checkInError != null) ...[
              const SizedBox(height: 12),
              Text(widget.state.checkInError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFF9D9D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
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
              ? BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          bottom: bottom
              ? BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          left: left
              ? BorderSide(color: RCColors.gold, width: t)
              : BorderSide.none,
          right: right
              ? BorderSide(color: RCColors.gold, width: t)
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
            Text(
                state.checkInAlready
                    ? 'Already checked in'
                    : 'Attendance recorded',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${state.checkInMeetingName} · ${state.checkInTimeLabel}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Week streak now 8 — keep it up!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RCColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: ElevatedButton(
                  onPressed: state.goToday,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RCColors.gold,
                    foregroundColor: RCColors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("See who's here today",
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: OutlinedButton(
                  onPressed: state.goAttendance,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View my attendance',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
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
    // A logged-in member here isn't a walk-in guest of this device's own
    // club — they're a Rotarian checking into a DIFFERENT club's meeting.
    final memberVisiting = state.authToken != null;
    // A real scanned QR already identifies the club — only the "Simulate
    // scan" fallback (no camera/printed QR to test with) needs it typed.
    final needsClubNameInput = state.scannedClubId == null && memberVisiting;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(memberVisiting ? 'Visiting another club' : 'Guest registration',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (needsClubNameInput) ...[
            _ScanInput(
              hint: 'Which club are you visiting?',
              value: state.guestClub,
              onChanged: state.setGuestClub,
              accent: true,
            ),
            const SizedBox(height: 12),
          ],
          _ScanInput(
              hint: 'Full name',
              value: state.guestName,
              onChanged: state.setGuestName),
          const SizedBox(height: 12),
          _ScanInput(
              hint: 'Phone number',
              value: state.guestPhone,
              onChanged: state.setGuestPhone),
          if (!memberVisiting) ...[
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
          ],
          if (state.guestFormError) ...[
            const SizedBox(height: 12),
            Text(
                needsClubNameInput
                    ? 'Please enter which club you\'re visiting, your name, and phone number.'
                    : "Please enter the guest's name and phone number.",
                style: const TextStyle(color: Color(0xFFFF9D9D), fontSize: 12)),
          ],
          if (state.guestSubmitError != null) ...[
            const SizedBox(height: 12),
            Text(state.guestSubmitError!,
                style: const TextStyle(color: Color(0xFFFF9D9D), fontSize: 12)),
          ],
          const SizedBox(height: 6),
          PressableScale(
            child: ElevatedButton(
              onPressed: state.guestSubmitting ? null : state.submitGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: RCColors.gold,
                foregroundColor: RCColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                  state.guestSubmitting
                      ? 'Registering…'
                      : 'Register & check in',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
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
    return PressableScale(
      child: ElevatedButton(
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
      ),
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
            Text(state.guestConfirmationLine,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text(state.guestStreakLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RCColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: ElevatedButton(
                  onPressed: state.goToday,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RCColors.gold,
                    foregroundColor: RCColors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("See who's here today",
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: OutlinedButton(
                  onPressed: state.resetScan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Register another guest',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
