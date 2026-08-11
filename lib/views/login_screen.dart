import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Native Cognito email/password login — fully in-app, no browser.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _drift;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.pendingEmail.isNotEmpty && _emailController.text.isEmpty) {
        _emailController.text = auth.pendingEmail;
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _drift.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final code = _codeController.text.trim();

    switch (auth.mode) {
      case AuthFormMode.signIn:
        await auth.signIn(email: email, password: password);
        return;
      case AuthFormMode.signUp:
        await auth.signUp(email: email, password: password);
        return;
      case AuthFormMode.confirm:
        await auth.confirmSignUp(
          email: email.isNotEmpty ? email : auth.pendingEmail,
          code: code,
          password: password.isNotEmpty ? password : null,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pulse, _drift]),
            builder: (context, _) {
              return CustomPaint(
                painter: _LoginBackdropPainter(
                  pulse: _pulse.value,
                  drift: _drift.value,
                ),
                size: size,
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: Tween(begin: 0.85, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  height: 1.05,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'TED',
                                    style: TextStyle(color: AppTheme.tedRed),
                                  ),
                                  TextSpan(
                                    text: 'x',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'MyTEDx',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Ideas worth spreading',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _titleForMode(auth.mode),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _subtitleForMode(auth.mode),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (auth.mode != AuthFormMode.confirm) ...[
                                _AuthField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: Icons.mail_outline_rounded,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),
                                _AuthField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  obscureText: _obscurePassword,
                                  textInputAction: auth.mode == AuthFormMode.signUp
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  validator: (value) =>
                                      _validatePassword(value, auth.mode),
                                  onFieldSubmitted: (_) {
                                    if (auth.mode == AuthFormMode.signIn) {
                                      _submit();
                                    }
                                  },
                                ),
                                if (auth.mode == AuthFormMode.signUp) ...[
                                  const SizedBox(height: 12),
                                  _AuthField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm password',
                                    obscureText: _obscureConfirm,
                                    textInputAction: TextInputAction.done,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm,
                                      ),
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match.';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                ],
                              ] else ...[
                                _AuthField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: Icons.mail_outline_rounded,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),
                                _AuthField(
                                  controller: _codeController,
                                  label: 'Confirmation code',
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: Icons.verified_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter the code from your email.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _AuthField(
                                  controller: _passwordController,
                                  label: 'Password (to sign in after confirm)',
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  validator: (value) {
                                    // Optional: if empty, user confirms then signs in manually.
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                              ],
                              if (auth.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  auth.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8A80),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                              if (auth.infoMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  auth.infoMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: auth.isBusy ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.tedRed,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        AppTheme.tedRed.withValues(alpha: 0.45),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: auth.isBusy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _buttonLabel(auth.mode),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._footerActions(auth),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Secured by Amazon Cognito',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _footerActions(AuthViewModel auth) {
    switch (auth.mode) {
      case AuthFormMode.signIn:
        return [
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () {
                    auth.setMode(AuthFormMode.signUp);
                    _confirmPasswordController.clear();
                  },
            child: const Text('Create an account'),
          ),
        ];
      case AuthFormMode.signUp:
        return [
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () => auth.setMode(AuthFormMode.signIn),
            child: const Text('Already have an account? Sign in'),
          ),
        ];
      case AuthFormMode.confirm:
        return [
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () => auth.resendCode(
                      _emailController.text.trim().isEmpty
                          ? auth.pendingEmail
                          : _emailController.text.trim(),
                    ),
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () => auth.setMode(AuthFormMode.signIn),
            child: const Text('Back to sign in'),
          ),
        ];
    }
  }

  String _titleForMode(AuthFormMode mode) {
    switch (mode) {
      case AuthFormMode.signIn:
        return 'Sign in';
      case AuthFormMode.signUp:
        return 'Create account';
      case AuthFormMode.confirm:
        return 'Confirm email';
    }
  }

  String _subtitleForMode(AuthFormMode mode) {
    switch (mode) {
      case AuthFormMode.signIn:
        return 'Enter your email and password to continue.';
      case AuthFormMode.signUp:
        return 'Register with email. You will receive a confirmation code.';
      case AuthFormMode.confirm:
        return 'Enter the code sent to your email, then continue.';
    }
  }

  String _buttonLabel(AuthFormMode mode) {
    switch (mode) {
      case AuthFormMode.signIn:
        return 'Sign in';
      case AuthFormMode.signUp:
        return 'Create account';
      case AuthFormMode.confirm:
        return 'Confirm and continue';
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _validatePassword(String? value, AuthFormMode mode) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (mode == AuthFormMode.signUp && password.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: AppTheme.tedRed,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: const Color(0xFF121212),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.tedRed, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8A80)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8A80)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _LoginBackdropPainter extends CustomPainter {
  _LoginBackdropPainter({
    required this.pulse,
    required this.drift,
  });

  final double pulse;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF050505),
          Color(0xFF120808),
          Color(0xFF000000),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final glowCenter = Offset(
      size.width * (0.25 + 0.15 * math.sin(drift * math.pi * 2)),
      size.height * (0.28 + 0.08 * math.cos(drift * math.pi * 2)),
    );
    final glowRadius = size.shortestSide * (0.42 + 0.08 * pulse);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.tedRed.withValues(alpha: 0.34 + 0.08 * pulse),
          AppTheme.tedRed.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius));
    canvas.drawCircle(glowCenter, glowRadius, glow);

    final secondary = Offset(
      size.width * (0.78 - 0.1 * math.cos(drift * math.pi * 2)),
      size.height * (0.72 + 0.06 * math.sin(drift * math.pi * 2)),
    );
    final secondaryRadius = size.shortestSide * 0.35;
    final secondaryPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3A1010).withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: secondary, radius: secondaryRadius),
      );
    canvas.drawCircle(secondary, secondaryRadius, secondaryPaint);

    final particlePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 18; i++) {
      final t = (drift + i / 18) % 1.0;
      final x = size.width * ((i * 0.137 + t * 0.2) % 1.0);
      final y = size.height *
          ((0.15 + i * 0.041 + math.sin(t * math.pi * 2 + i) * 0.04) % 1.0);
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoginBackdropPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.drift != drift;
  }
}
