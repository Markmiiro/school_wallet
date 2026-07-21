// Registration screen — new parent creates an account with name,
// phone, and a 4-digit PIN (entered twice to confirm). On success,
// AuthProvider auto-logs them in and we navigate to the dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (rawPhone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = 'Your PIN must be exactly 4 digits.');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _error = 'PINs do not match. Please re-enter.');
      return;
    }

    // Convert local number (0771234567) to backend's 256XXXXXXXXX format.
    String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '256${phone.substring(1)}';
    } else if (!phone.startsWith('256')) {
      phone = '256$phone';
    }

    setState(() => _error = null);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      name: name,
      phone: phone,
      pin: pin,
    );

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      setState(() => _error = authProvider.errorMessage ?? 'Registration failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 52,
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spaceLg),
              Text('Join School Wallet', style: AppTheme.headlineLgMobile)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'Create a parent account to manage your children\'s wallets.',
                style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: AppTheme.spaceXl),

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
                    Text('Full Name',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'e.g. Sarah Musitwa'),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('Phone Number',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        prefixText: '+256 ',
                        hintText: '700 000 000',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('Create a 4-Digit PIN',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Pinput(
                      controller: _pinController,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: '●',
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('Confirm PIN',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Pinput(
                      controller: _confirmPinController,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: '●',
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      Text(_error!,
                          style: AppTheme.bodySm.copyWith(color: AppColors.error)),
                    ],

                    const SizedBox(height: AppTheme.spaceLg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleSubmit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: AppTheme.spaceLg),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Already have an account? Log in',
                    style: AppTheme.bodySm.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}