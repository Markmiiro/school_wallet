// Premium Dashboard. Greeting header, a hero card that switches between
// a waiting state (no children yet) and a total-family-balance state
// (has children), a quick-actions row (Buy a Card / History), and child
// cards showing school, account number and an animated balance count-up.
//
// Parents do not create children here. A child is registered by the
// school (or by USSD) against the parent's phone number and then shows
// up in this list; the parent links a card from the child's wallet.
//
// NOTE: "Buy a Card" is a first-class action. Per the approved USSD
// spec, registering a child = buying their UGX 25,000 card. The full
// paid flow needs backend model changes (dob/class/card_color) — for
// now this routes to the card-preview screen as a showcase.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../data/models/student.dart';
import '../../../data/models/wallet_balance.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../wallet/screens/child_wallet_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// Switches the shell to the Transactions tab.
  final VoidCallback? onOpenTransactions;

  const DashboardScreen({super.key, this.onOpenTransactions});

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

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  double get _totalBalance {
    final wallet = context.read<WalletProvider>();
    double sum = 0;
    for (final s in wallet.students) {
      final b = wallet.balanceFor(s.id);
      if (b != null) sum += b.balance;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.currentUser;
    final hasChildren = walletProvider.students.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile, AppTheme.spaceLg,
              AppTheme.marginMobile, AppTheme.spaceXl,
            ),
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 26),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text('Nuvora', style: AppTheme.headlineMd),
                  const Spacer(),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryContainer.withOpacity(0.2),
                    child: Text(
                      _initials(user?.name),
                      style: AppTheme.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.spaceLg),

              Text('Welcome back,',
                  style: AppTheme.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              Text(user?.name ?? 'there', style: AppTheme.headlineLgMobile)
                  .animate()
                  .fadeIn(delay: 80.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: AppTheme.spaceLg),

              // Hero card — switches on whether children exist
              if (hasChildren)
                _totalBalanceCard(walletProvider)
              else
                _onboardingCard(user?.phone),

              const SizedBox(height: AppTheme.spaceLg),

              // Quick actions
              _quickActions(hasChildren),

              const SizedBox(height: AppTheme.spaceLg),

              // Children section
              Row(
                children: [
                  Text('Your Children', style: AppTheme.headlineMd),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),

              if (walletProvider.isLoading && !hasChildren)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spaceXl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!hasChildren)
                _emptyChildrenPlaceholder()
              else
                ...walletProvider.students.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  final balance = walletProvider.balanceFor(student.id);
                  return _childCard(student, balance, index);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalBalanceCard(WalletProvider wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [AppColors.level2Shadow],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0, top: 0,
            child: Icon(Icons.shield_rounded,
                color: AppColors.onPrimaryContainer.withOpacity(0.15), size: 28),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total family balance',
                  style: AppTheme.bodySm.copyWith(color: AppColors.onPrimaryContainerMuted)),
              const SizedBox(height: AppTheme.spaceXs),
              AnimatedBalanceCounter(
                balance: _totalBalance,
                style: AppTheme.displayCurrency.copyWith(color: AppColors.onPrimaryContainer),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onSecondaryContainer,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () {
                  // A top-up is always for one child. With one child, go
                  // straight to their wallet; otherwise ask which.
                  if (wallet.students.length == 1) {
                    _openChild(wallet.students.first);
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Choose a child below to top up their wallet.'),
                    ),
                  );
                },
                child: const Text('Top Up Wallet'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _onboardingCard(String? phone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [AppColors.level2Shadow],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.onPrimaryContainer.withOpacity(0.15),
            child: const Icon(Icons.school_rounded,
                color: AppColors.onPrimaryContainer, size: 28),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text('No children linked yet', style: AppTheme.headlineMd.copyWith(color: AppColors.onPrimaryContainer)),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'Your child appears here once the school has registered them '
            'under your phone number${phone != null ? ' ($phone)' : ''}. '
            'Ask the school office, then pull down to refresh.',
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(color: AppColors.onPrimaryContainerMuted),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
            ),
            onPressed: _load,
            child: const Text('Check again'),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _quickActions(bool hasChildren) {
    return Row(
      children: [
        _actionTile(Icons.credit_card_rounded, 'Buy a Card', true, () {
          context.push('/buy-card');
        }),
        const SizedBox(width: AppTheme.spaceMd),
        _actionTile(Icons.receipt_long_rounded, 'History', hasChildren,
            () => widget.onOpenTransactions?.call()),
      ],
    ).animate().fadeIn(delay: 160.ms);
  }

  Widget _actionTile(IconData icon, String label, bool enabled, VoidCallback onTap) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.level1CardBorder),
              ),
              child: Column(
                children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySm.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyChildrenPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 30, color: AppColors.outlineVariant),
          const SizedBox(height: AppTheme.spaceSm),
          Text('No children linked yet',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _openChild(Student student) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChildWalletDetailScreen(student: student),
      ),
    );
    // A top-up, a new limit or a blocked card may have happened in there.
    if (mounted) _load();
  }

  Widget _childCard(Student student, WalletBalance? balance, int index) {
    final schoolLine = [
      if (student.schoolName != null) student.schoolName!,
      if (student.accountNumber != null) 'Acc ${student.accountNumber}',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => _openChild(student),
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
                radius: 22,
                backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
                child: Icon(Icons.school_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: AppTheme.headlineMd.copyWith(fontSize: 17)),
                    if (schoolLine.isNotEmpty)
                      Text(
                        schoolLine,
                        style: AppTheme.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    if (balance == null)
                      Text('Balance unavailable',
                          style: AppTheme.bodySm
                              .copyWith(color: AppColors.onSurfaceVariant))
                    else
                      AnimatedBalanceCounter(
                        balance: balance.balance,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 20, color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}