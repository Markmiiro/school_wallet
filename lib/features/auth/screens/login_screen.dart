// Real Login screen, styled from the Stitch design export.
// Phone number + 4-digit PIN (pinput), shake + inline error on
// incomplete/invalid PIN, loading state on submit, a link to
// Registration, and a subtle entrance animation via flutter_animate.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  late final AnimationController _shakeController;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _phoneFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  Future<void> _handleSubmit() async {
    final rawPhone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      setState(() => _pinError = 'Enter all 4 digits of your PIN.');
      _triggerShake();
      return;
    }

    if (rawPhone.isEmpty) {
      setState(() => _pinError = null);
      _triggerShake();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your phone number.')),
      );
      return;
    }

    // Convert a locally-typed number (e.g. 0771234567) into the
    // backend's required 256XXXXXXXXX format.
    String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '256${phone.substring(1)}';
    } else if (!phone.startsWith('256')) {
      phone = '256$phone';
    }

    setState(() => _pinError = null);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(phone, pin);

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      setState(() {
        _pinError = authProvider.errorMessage ?? 'Login failed.';
      });
      _triggerShake();
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTheme.labelMono.copyWith(fontSize: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: AppColors.outline),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 1.5),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spaceLg),

              // Brand row
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text('School Wallet', style: AppTheme.headlineMd),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.spaceXl),

              // Secure login pill badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'SECURE LOGIN',
                      style: AppTheme.labelMono.copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: AppTheme.spaceMd),

              Text('Welcome Back', style: AppTheme.headlineLgMobile)
                  .animate()
                  .fadeIn(delay: 150.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'Access your UGX funds safely and securely.',
                style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: AppTheme.spaceXl),

              // Card container
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppColors.level1CardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone Number',
                        style: AppTheme.bodySm
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        prefixText: '+256 ',
                        hintText: '700 000 000',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('Secure 4-Digit PIN',
                        style: AppTheme.bodySm
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),

                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final shake =
                            (1 - _shakeController.value) *
                            8 *
                            (1 - (2 * _shakeController.value - 1).abs()) *
                            (_shakeController.value == 0
                                ? 0
                                : (_shakeController.value * 40).round() % 2 ==
                                        0
                                    ? 1
                                    : -1);
                        return Transform.translate(
                          offset: Offset(shake, 0),
                          child: child,
                        );
                      },
                      child: Pinput(
                        controller: _pinController,
                        length: 4,
                        obscureText: true,
                        obscuringCharacter: '●',
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        errorPinTheme: errorPinTheme,
                        forceErrorState: _pinError != null,
                        onChanged: (_) {
                          if (_pinError != null) {
                            setState(() => _pinError = null);
                          }
                        },
                        onCompleted: (_) => _handleSubmit(),
                      ),
                    ),

                    if (_pinError != null) ...[
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                        _pinError!,
                        style: AppTheme.bodySm.copyWith(color: AppColors.error),
                      ),
                    ],

                    const SizedBox(height: AppTheme.spaceLg),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            authProvider.isLoading ? null : _handleSubmit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue to Wallet'),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceMd),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Forgot PIN flow — not built yet.
                        },
                        child: Text(
                          '❓ Forgot PIN?',
                          style: AppTheme.bodySm
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: AppTheme.spaceLg),

              // Link to Registration
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    'New here? Create an account',
                    style: AppTheme.bodySm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: AppTheme.spaceMd),

              Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        color: AppColors.onSurfaceVariant, size: 28),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text('End-to-End Encrypted Data',
                        style: AppTheme.bodySm),
                    Text(
                      'Bank-grade security for your academic savings.',
                      style: AppTheme.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}