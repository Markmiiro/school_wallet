// The app lock's screen, laid over whatever the parent was looking at.
//
// LockGate wraps the whole router (MaterialApp.router's builder), so the
// screens underneath keep their state: unlocking lands the parent exactly
// where they were. It also tells AppLock when the app goes to the
// background and comes back. While locked, nothing underneath can take
// focus or taps.

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../core/biometric/biometric.dart';
import '../../core/constants/app_colors.dart';
import '../../core/device_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_lock.dart';
import '../../providers/auth_provider.dart';

/// Where this device keeps a parent's biometric credential id. Per user,
/// so a second parent signing in on the same phone cannot use the first
/// one's fingerprint.
String biometricKey(int userId) => 'biometric_credential_$userId';

class LockGate extends StatefulWidget {
  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  late final AppLifecycleListener _lifecycle;
  late final OverlayEntry _lockEntry =
      OverlayEntry(builder: (_) => const LockScreen());

  @override
  void initState() {
    super.initState();
    final lock = context.read<AppLock>();
    _lifecycle = AppLifecycleListener(
      onHide: lock.onHidden,
      onShow: lock.onShown,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<AppLock>().locked &&
        context.watch<AuthProvider>().isLoggedIn;
    return Stack(
      children: [
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(excluding: locked, child: widget.child),
        ),
        if (locked)
          // Its own Overlay: the router's sits inside `child`, below us,
          // and text fields need one above them.
          Positioned.fill(child: Overlay(initialEntries: [_lockEntry])),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  final _prefs = SecureDevicePrefs();
  bool _busy = false;
  String? _error;
  String? _credentialId; // set when this device can unlock by biometric

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final id = await _prefs.read(biometricKey(userId));
    if (id == null || !await Biometric.available()) return;
    if (mounted) setState(() => _credentialId = id);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin(String pin) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await context.read<AppLock>().unlockWithPin(pin);
    if (!mounted) return;
    _pinController.clear();
    setState(() {
      _busy = false;
      _error = problem;
    });
  }

  Future<void> _useBiometric() async {
    final lock = context.read<AppLock>();
    setState(() => _error = null);
    if (await Biometric.verify(_credentialId!)) {
      await lock.unlockedByBiometric();
    } else if (mounted) {
      setState(() => _error = 'Not recognised. Enter your PIN instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthProvider>().currentUser?.name;
    final pinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTheme.labelMono.copyWith(fontSize: 22, color: AppColors.onPrimary),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: AppColors.onPrimaryContainerMuted),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: AppColors.onPrimary, size: 40),
                const SizedBox(height: AppTheme.spaceMd),
                Text('Nuvora is locked',
                    style: AppTheme.headlineMd.copyWith(color: AppColors.onPrimary)),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  name == null ? 'Enter your PIN' : 'Enter your PIN, $name',
                  style: AppTheme.bodyMd.copyWith(color: AppColors.onPrimaryContainerMuted),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  autofocus: true,
                  enabled: !_busy,
                  defaultPinTheme: pinTheme,
                  focusedPinTheme: pinTheme.copyDecorationWith(
                    border: Border.all(color: AppColors.secondaryContainer, width: 2),
                  ),
                  onCompleted: _submitPin,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                SizedBox(
                  height: 40,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onPrimary),
                        )
                      : _error != null
                          ? Text(_error!,
                              textAlign: TextAlign.center,
                              style: AppTheme.bodySm.copyWith(color: AppColors.errorContainer))
                          : null,
                ),
                if (_credentialId != null) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                    ),
                    onPressed: _busy ? null : _useBiometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Use fingerprint or face'),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceXl),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.onPrimary),
                  onPressed: () => context.read<AuthProvider>().logout(),
                  child: const Text('Not you? Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
