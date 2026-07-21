// Profile screen. Shows the logged-in parent's details (from cached
// AuthProvider state) and provides Change PIN and Log Out actions.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

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

            OutlinedButton.icon(
              onPressed: () => context.push('/change-pin'),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Change PIN'),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: AppTheme.spaceMd),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
            ).animate().fadeIn(delay: 200.ms),
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