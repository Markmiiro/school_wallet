// Real Dashboard screen. Lists the parent's children as cards with
// animated balance count-up, staggered fade/slide entrance, and a
// friendly empty state. Pull-to-refresh reloads from the backend.
// Tapping a child's card navigates to their Child Wallet Detail screen.
// The profile icon in the app bar opens the Profile screen (which
// holds the Log Out and Change PIN actions).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../wallet/screens/child_wallet_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final parentId = authProvider.currentUser?.id;
    if (parentId != null) {
      await walletProvider.loadForParent(parentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(walletProvider, user?.name),
      ),
    );
  }

  Widget _buildBody(WalletProvider walletProvider, String? parentName) {
    if (walletProvider.isLoading && walletProvider.students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (walletProvider.errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: AppTheme.spaceMd),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.marginMobile,
              ),
              child: Text(
                walletProvider.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Center(
            child: ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (walletProvider.students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No children registered yet.',
              style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-child'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a Child'),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      itemCount: walletProvider.students.length,
      itemBuilder: (context, index) {
        final student = walletProvider.students[index];
        final balance = walletProvider.balanceFor(student.id);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ChildWalletDetailScreen(student: student),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.level1CardBorder),
                boxShadow: [AppColors.level2Shadow],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
                    child: Icon(Icons.school_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: AppTheme.headlineMd),
                        const SizedBox(height: 4),
                        if (balance == null)
                          Text(
                            'Balance unavailable',
                            style: AppTheme.bodySm
                                .copyWith(color: AppColors.onSurfaceVariant),
                          )
                        else ...[
                          AnimatedBalanceCounter(
                            balance: balance.balance,
                            style: AppTheme.displayCurrency.copyWith(
                              fontSize: 22,
                              color: AppColors.primary,
                            ),
                          ),
                          if (!balance.isActive)
                            Text(
                              'Wallet inactive',
                              style: AppTheme.bodySm
                                  .copyWith(color: AppColors.error),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }
}