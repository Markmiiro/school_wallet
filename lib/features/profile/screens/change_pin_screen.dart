// Change PIN screen. Current PIN + new PIN + confirm. On success
// AuthProvider.changePin logs the user out; the router then returns to
// Login on its own, where they sign in with the new PIN.

import 'package:flutter/material.dart';
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
    // Taken before the await: on success the router leaves this screen
    // as soon as the provider logs out, so `context` is gone by then.
    final messenger = ScaffoldMessenger.of(context);
    final success = await authProvider.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('PIN changed. Log in again with your new PIN.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _error = authProvider.errorMessage ?? 'Could not change PIN.');
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
        child: SingleChildScrollView(
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
                              strokeWidth: 2, color: AppColors.onSurfaceVariant),
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
}
