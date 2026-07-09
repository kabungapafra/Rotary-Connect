import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/wordmark.dart';

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
                      child: Material(
                        color: RCColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: state.goSplash,
                          child: const SizedBox(
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 22),
                            Wordmark(state: state, scale: 0.8),
                            const SizedBox(height: 22),
                            const Text(
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
                            const Text(
                              'Forgot PIN?',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: RCColors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // box-shadow: 0 8px 20px rgba(23,69,143,.28)
                    DecoratedBox(
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
                        onPressed: state.loginLoading ? null : state.submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(17),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(state.loginLoading ? 'Signing in…' : 'Log in',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
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
                                child: const Text(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
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
    );
  }
}
