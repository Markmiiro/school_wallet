// Change PIN screen. Current PIN + new PIN + confirm. On success the
// backend invalidates the session, so AuthProvider.changePin logs the
// user out and we send them back to Login to sign in with the new PIN.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin.length != 4) {
      setState(() => _error = 'Enter your current 4-digit PIN.');
      return;
    }
    if (newPin.length != 4) {
      setState(() => _error = 'New PIN must be exactly 4 digits.');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _error = 'New PINs do not match.');
      return;
    }
    if (newPin == currentPin) {
      setState(() => _error = 'New PIN must be different from the current one.');
      return;
    }

    setState(() => _error = null);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _success = true);
    } else {
      setState(() => _error = authProvider.errorMessage ?? 'Could not change PIN.');
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
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: _success
            ? _buildSuccess()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.marginMobile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current PIN',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Pinput(
                      controller: _currentPinController,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: '●',
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('New PIN',
                        style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Pinput(
                      controller: _newPinController,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: '●',
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    Text('Confirm New PIN',
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

                    const SizedBox(height: AppTheme.spaceXl),
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
                            : const Text('Update PIN'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 72)
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppTheme.spaceLg),
            Text('PIN Changed', style: AppTheme.headlineMd)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Please log in again with your new PIN.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}