import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'push_service.dart';
import 'theme.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/photo_viewer.dart';
import 'widgets/certificate_modal.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/today_screen.dart';
import 'screens/home_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/treasury_screen.dart';
import 'screens/secretary_screen.dart';
import 'screens/club_history_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/events_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/members_screen.dart';
import 'screens/club_suspended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const RotaryMbalwaApp());
}

class RotaryMbalwaApp extends StatefulWidget {
  const RotaryMbalwaApp({super.key});

  @override
  State<RotaryMbalwaApp> createState() => _RotaryMbalwaAppState();
}

class _RotaryMbalwaAppState extends State<RotaryMbalwaApp> {
  final AppState state = AppState();
  // Tracks the tab shown in the previous build so leaving the splash
  // screen specifically can get its own, more deliberate transition —
  // the app's one grand-entrance moment — instead of the quick, subtle
  // cross-fade used for ordinary in-app navigation.
  String _previousTab = 'splash';

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    // Firebase may not be available (misconfigured, no Play Services, or —
    // as with `flutter test`'s widget harness — no platform channel at
    // all): push notifications just won't work rather than taking the
    // whole app down on launch.
    try {
      PushService.instance.onToken = state.registerPushToken;
      PushService.instance.init().catchError((Object e) {
        debugPrint('Push notification setup failed: $e');
      });
      FirebaseMessaging.onMessageOpenedApp.listen(state.handlePushTap);
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) state.handlePushTap(message);
      });
    } catch (e) {
      debugPrint('Push notifications unavailable: $e');
    }
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  Widget _screenFor(String tab) {
    switch (tab) {
      case 'splash':
        return SplashScreen(state: state);
      case 'login':
        return LoginScreen(state: state);
      case 'today':
        return TodayScreen(state: state);
      case 'home':
        return HomeScreen(state: state);
      case 'gallery':
        return GalleryScreen(state: state);
      case 'treasury':
        return TreasuryScreen(state: state);
      case 'secretary':
        return SecretaryScreen(state: state);
      case 'history':
        return ClubHistoryScreen(state: state);
      case 'scan':
        return ScanScreen(state: state);
      case 'attendance':
        return AttendanceScreen(state: state);
      case 'events':
        return EventsScreen(state: state);
      case 'projects':
        return ProjectsScreen(state: state);
      case 'members':
        return MembersScreen(state: state);
      case 'suspended':
        return ClubSuspendedScreen(state: state);
      default:
        return HomeScreen(state: state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotary Club of Mbalwa',
      debugShowCheckedModeBanner: false,
      theme: buildRCTheme(),
      home: PopScope(
        canPop: !state.canGoBack,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          state.goBack();
        },
        child: Scaffold(
          backgroundColor: RCColors.scaffoldBg,
          body: Stack(
            children: [
              Column(
                children: [
                  // Screen-to-screen transition: quick cross-fade with a
                  // subtle upward slide on every tab change — except
                  // leaving the splash screen, which gets a slower,
                  // more deliberate fade + rise + gentle scale-in.
                  Expanded(
                    child: Builder(builder: (context) {
                      final leavingSplash =
                          _previousTab == 'splash' && state.tab != 'splash';
                      _previousTab = state.tab;
                      return AnimatedSwitcher(
                        duration:
                            Duration(milliseconds: leavingSplash ? 460 : 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => leavingSplash
                            ? FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, .06),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic)),
                                  child: ScaleTransition(
                                    scale: Tween(begin: .96, end: 1.0).animate(
                                        CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic)),
                                    child: child,
                                  ),
                                ),
                              )
                            : FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, .015),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                        child: KeyedSubtree(
                          key: ValueKey(state.tab),
                          child: _screenFor(state.tab),
                        ),
                      );
                    }),
                  ),
                  // Hidden on splash/login/scan/suspended and whenever a
                  // bottom sheet (event/project/member editor, gallery
                  // upload) is open.
                  if (state.tab != 'splash' &&
                      state.tab != 'login' &&
                      state.tab != 'scan' &&
                      state.tab != 'suspended' &&
                      state.eventEditor == null &&
                      state.eventQR == null &&
                      state.projectEditor == null &&
                      state.memberEditor == null &&
                      state.memberProfile == null &&
                      state.uploadSheet == null &&
                      state.apologySheet == null &&
                      state.voteEditor == null &&
                      state.txEntry == null &&
                      state.duesSettingEditor == null &&
                      state.minuteEditor == null &&
                      state.milestoneEditor == null)
                    BottomNav(state: state),
                ],
              ),
              if (state.photo != null) PhotoViewerOverlay(state: state),
              if (state.cert != null) CertificateModal(state: state),
            ],
          ),
        ),
      ),
    );
  }
}
