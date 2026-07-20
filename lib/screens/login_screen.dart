import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/pressable.dart';
import '../widgets/wordmark.dart';
import '../widgets/synced_text_field.dart';

class LoginScreen extends StatelessWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White screen needs dark status-bar icons; the rest of the app uses light.
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Same pale corner circles as the splash.
            Positioned(
              top: -140,
              right: -140,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: RCColors.scaffoldBg,
                ),
              ),
            ),
            Positioned(
              top: -168.8,
              right: -168.8,
              child: Container(
                width: 377.6,
                height: 377.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: RCColors.blue.withValues(alpha: .08), width: 1.5),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 84, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PressableScale(
                        child: Material(
                          color: RCColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: state.goSplash,
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                child: Text('‹',
                                    style: TextStyle(
                                        color: RCColors.blue, fontSize: 16)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 22),
                            Wordmark(state: state, scale: 0.8),
                            const SizedBox(height: 22),
                            Text(
                              'Member login',
                              style: TextStyle(
                                color: RCColors.blue,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in with your member number and PIN.',
                              style: TextStyle(
                                color: RCColors.textMuted,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const _FieldLabel('MEMBER NUMBER OR PHONE'),
                            const SizedBox(height: 6),
                            _LoginInput(
                              hint: 'e.g. RCM-0042 or 0772 000 000',
                              value: state.loginId,
                              onChanged: state.setLoginId,
                            ),
                            const SizedBox(height: 12),
                            const _FieldLabel('PIN'),
                            const SizedBox(height: 6),
                            _LoginInput(
                              hint: '••••',
                              value: state.loginPin,
                              onChanged: state.setLoginPin,
                              obscure: true,
                            ),
                            if (state.loginError) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.loginErrorMessage,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: RCColors.red),
                              ),
                            ],
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _showForgotPinDialog(context),
                              child: Text(
                                'Forgot PIN?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: RCColors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // box-shadow: 0 8px 20px rgba(23,69,143,.28)
                    PressableScale(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: RCColors.blue.withValues(alpha: .28),
                              offset: const Offset(0, 8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              state.loginLoading ? null : state.submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RCColors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(17),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                              state.loginLoading ? 'Signing in…' : 'Log in',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: 'Visiting? ',
                          style: const TextStyle(
                              fontSize: 12, color: RCColors.textMuted),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: state.enterGuest,
                                child: Text(
                                  'Continue as a Guest',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: RCColors.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(
                              'https://rotary.digiflecttech.dev/privacy.html'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Privacy Policy',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: RCColors.textMuted,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPinDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _ForgotPinDialog(state: state),
    );
  }
}

/// Self-service PIN reset. Talks to POST /auth/forgot-pin directly — no
/// admin needs to be involved. Capped server-side at 3 resets per member
/// per 30 days; the server's response is identical whether the identifier
/// was real, unknown, or already over its cap, so this dialog can't be
/// used to tell those cases apart either (that's the whole point — it's
/// what keeps the endpoint from leaking which member numbers are real).
class _ForgotPinDialog extends StatefulWidget {
  final AppState state;
  const _ForgotPinDialog({required this.state});

  @override
  State<_ForgotPinDialog> createState() => _ForgotPinDialogState();
}

class _ForgotPinDialogState extends State<_ForgotPinDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.state.loginId);
  bool _sending = false;
  // null = not submitted yet; true = request reached the server (its own
  // response is always the same generic message, matched or not); false =
  // couldn't reach the server at all.
  bool? _sent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _controller.text.trim();
    if (identifier.isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.state.requestPinReset(identifier);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
    });
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Forgot your PIN?',
          style: TextStyle(
              color: RCColors.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800)),
      content: _sent == true
          ? const Text(
              'If that member number or phone is registered, we\'ve just '
              'texted a new PIN to it. You can do this up to 3 times every '
              '30 days.',
              style: TextStyle(color: RCColors.textMuted, fontSize: 13.5))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Enter your member number or phone and we\'ll text a '
                    'new PIN to it.',
                    style:
                        TextStyle(color: RCColors.textMuted, fontSize: 13.5)),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  enabled: !_sending,
                  autofocus: true,
                  style: const TextStyle(
                      color: RCColors.textDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. RCM-0042 or 0772 000 000',
                    hintStyle: const TextStyle(color: Color(0xFF8B96A8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: _border(const Color(0xFFD4DBE8)),
                    enabledBorder: _border(const Color(0xFFD4DBE8)),
                    focusedBorder: _border(RCColors.blue),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                    'Reached your limit or no phone access? Email '
                    'digiflecttech@gmail.com.',
                    style: TextStyle(
                        color: RCColors.textMuted.withValues(alpha: 0.85),
                        fontSize: 11.5)),
                if (_sent == false) ...[
                  const SizedBox(height: 10),
                  const Text(
                      'Couldn\'t reach the server — check your connection '
                      'and try again.',
                      style: TextStyle(
                          color: RCColors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
      actions: _sent == true
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Got it',
                    style: TextStyle(
                        color: RCColors.blue, fontWeight: FontWeight.w700)),
              ),
            ]
          : [
              TextButton(
                onPressed:
                    _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: RCColors.textMuted,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Send new PIN',
                        style: TextStyle(
                            color: RCColors.blue,
                            fontWeight: FontWeight.w700)),
              ),
            ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Color(0xFF8B96A8),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;
  const _LoginInput({
    required this.hint,
    required this.value,
    required this.onChanged,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return SyncedTextField(
      value: value,
      builder: (context, controller) => TextField(
        controller: controller,
        onChanged: onChanged,
        obscureText: obscure,
        style: TextStyle(
          color: RCColors.textDark,
          fontSize: 14,
          letterSpacing: obscure ? 3 : 0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B96A8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: border(const Color(0xFFD4DBE8)),
          enabledBorder: border(const Color(0xFFD4DBE8)),
          focusedBorder: border(RCColors.blue),
        ),
    ),
           );
  }
}
