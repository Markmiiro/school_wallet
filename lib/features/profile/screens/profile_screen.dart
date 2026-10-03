// Profile screen. Shows the logged-in parent's details (from cached
// AuthProvider state) and provides Lock, fingerprint/face unlock (where
// the phone supports it), Change PIN, Support, Log Out and Delete account,
// with the app version at the foot.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/biometric/biometric.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/device_prefs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/support_links.dart';
import '../../../providers/app_lock.dart';
import '../../../providers/auth_provider.dart';
import '../../lock/lock_gate.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppTheme.spaceMd),

            // Avatar + name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
                    child: Icon(Icons.person_rounded,
                        size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(user?.name ?? 'Unknown', style: AppTheme.headlineLgMobile),
                  const SizedBox(height: 4),
                  Text(
                    (user?.role ?? '').toUpperCase(),
                    style: AppTheme.labelMono.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: AppTheme.spaceXl),

            // Details card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.level1CardBorder),
              ),
              child: Column(
                children: [
                  _detailRow(Icons.phone_rounded, 'Phone', user?.phone ?? '—'),
                  const Divider(height: AppTheme.spaceLg),
                  _detailRow(
                    Icons.badge_rounded,
                    'Role',
                    user?.role ?? '—',
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: AppTheme.spaceXl),

            // Locks without signing out; the PIN brings the parent back here.
            OutlinedButton.icon(
              onPressed: () => context.read<AppLock>().lock(),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Lock app'),
            ).animate().fadeIn(delay: 120.ms),

            if (user != null) _BiometricSetting(userId: user.id, name: user.name),

            const SizedBox(height: AppTheme.spaceMd),

            OutlinedButton.icon(
              onPressed: () => context.push('/change-pin'),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Change PIN'),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: AppTheme.spaceMd),

            SupportLinks(screen: 'Profile', account: user?.phone)
                .animate()
                .fadeIn(delay: 175.ms),

            const SizedBox(height: AppTheme.spaceMd),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
              ),
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppTheme.spaceXl),

            // Kept apart from Log Out and plain, so it is not hit by
            // mistake; the screen behind it asks for the PIN and DELETE.
            if (user?.role == 'parent')
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () => context.push('/delete-account'),
                child: const Text('Delete account'),
              ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: AppTheme.spaceLg),
            const AppVersionLine(),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: AppTheme.spaceMd),
        Text(label, style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// "Unlock with fingerprint or face". Shown only where the phone has a
/// sensor the browser can use; most cheap Android does not, and there the
/// lock screen simply asks for the PIN.
class _BiometricSetting extends StatefulWidget {
  final int userId;
  final String name;

  const _BiometricSetting({required this.userId, required this.name});

  @override
  State<_BiometricSetting> createState() => _BiometricSettingState();
}

class _BiometricSettingState extends State<_BiometricSetting> {
  final _prefs = SecureDevicePrefs();
  bool _available = false;
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final available = await Biometric.available();
    final id = await _prefs.read(biometricKey(widget.userId));
    if (!mounted) return;
    setState(() {
      _available = available;
      _on = id != null;
    });
  }

  Future<void> _toggle(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    if (on) {
      final id = await Biometric.enroll('Nuvora ${widget.userId}', widget.name);
      if (id == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not set up fingerprint or face unlock.')));
      } else {
        await _prefs.write(biometricKey(widget.userId), id);
      }
    } else {
      await _prefs.write(biometricKey(widget.userId), null);
    }
    await _check();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceSm),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Unlock with fingerprint or face'),
        subtitle: const Text('Checked on this phone only. Your PIN still works.'),
        value: _on,
        onChanged: _busy ? null : _toggle,
      ),
    );
  }
}
