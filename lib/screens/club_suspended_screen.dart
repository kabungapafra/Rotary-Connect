import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

/// Shown instead of the normal app whenever the signed-in member's club has
/// been suspended by the system admin — checked at login and opportunistically
/// on every AppState.loadSummary() call, so it also catches a club suspended
/// while a member is already mid-session. The only action available is
/// logging out; there is nothing else to do here until the club is
/// reinstated.
class ClubSuspendedScreen extends StatelessWidget {
  final AppState state;
  const ClubSuspendedScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: RCColors.red.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('⛔', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Club Suspended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: RCColors.textDark,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${state.clubName} has been suspended by the system admin. '
                "You won't be able to use the app until your club is "
                'reinstated — contact your club president for details.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: RCColors.textMuted,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 4),
              PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RCColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Log Out',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
