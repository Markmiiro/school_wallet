// Family Transactions feed. Merges every child's wallet history into
// one newest-first timeline, grouped by day, with a filter per child:
// the parent's real question is what one child spent. Totals follow the
// filter. Rows come from core/widgets/activity_feed.dart.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/activity_feed.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // Null shows the whole family.
  int? _studentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    // Make sure students are loaded first, then their transactions.
    if (wallet.students.isEmpty && auth.currentUser != null) {
      await wallet.loadForParent(auth.currentUser!.id);
    }
    await wallet.loadFamilyTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(wallet),
      ),
    );
  }

  Widget _buildBody(WalletProvider wallet) {
    if (wallet.isHistoryLoading && wallet.familyTransactions.isEmpty) {
      return _shimmerList();
    }

    // A child who is no longer in the list falls back to the family.
    final student = wallet.students.where((s) => s.id == _studentId).firstOrNull;
    final studentId = student?.id;
    final items = activityFor(wallet.familyTransactions, studentId);
    final firstName = student?.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        if (wallet.students.length > 1) ...[
          _childFilter(wallet, studentId),
          const SizedBox(height: AppTheme.spaceMd),
        ],

        // Totals row
        Row(
          children: [
            Expanded(
              child: _totalTile(
                label: 'Topped up',
                value: wallet.totalInFor(studentId),
                color: AppColors.moneyIn,
                icon: Icons.add_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _totalTile(
                label: 'Spent',
                value: wallet.totalOutFor(studentId),
                color: AppColors.moneyOut,
                icon: Icons.storefront_rounded,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: AppTheme.spaceLg),

        Text(
          firstName == null ? 'Recent activity' : '$firstName\'s activity',
          style: AppTheme.headlineMd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppTheme.spaceSm),

        if (items.isEmpty)
          _emptyState(firstName)
        else ...[
          // Top-ups but no purchase yet: say so rather than leave the
          // parent wondering whether purchases are missing.
          if (firstName != null && !hasSpent(items) && wallet.totalOutFor(studentId) == 0)
            NothingSpentNote(name: firstName),
          ActivityFeed(items: items, showChild: studentId == null)
              .animate()
              .fadeIn(duration: 350.ms),
        ],
      ],
    );
  }

  // "All" and one chip per child, scrolling sideways when they do not fit.
  Widget _childFilter(WalletProvider wallet, int? selected) {
    Widget chip(String label, int? id) {
      final on = selected == id;
      return Padding(
        padding: const EdgeInsets.only(right: AppTheme.spaceSm),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => setState(() => _studentId = id),
          selectedColor: AppColors.secondaryContainer,
          backgroundColor: AppColors.surfaceContainerLowest,
          side: BorderSide(
            color: on ? AppColors.secondaryContainer : AppColors.level1CardBorder,
          ),
          labelStyle: AppTheme.bodySm.copyWith(
            fontWeight: FontWeight.w600,
            color: on ? AppColors.onSecondaryContainer : AppColors.onSurface,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', null),
          for (final s in wallet.students) chip(s.name.split(' ').first, s.id),
        ],
      ),
    );
  }

  Widget _totalTile({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: AppTheme.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Shrinks rather than wraps on a narrow phone.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedBalanceCounter(
              balance: value,
              style: AppTheme.headlineMd.copyWith(color: color, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String? firstName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXl * 1.5),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                    size: 48, color: AppColors.outlineVariant)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn()
                .moveY(begin: -4, end: 4, duration: 1600.ms),
            const SizedBox(height: AppTheme.spaceMd),
            Text(firstName == null ? 'No transactions yet' : '$firstName has no activity yet',
                style: AppTheme.headlineMd
                    .copyWith(color: AppColors.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              firstName == null
                  ? 'Top-ups and tuck-shop purchases will show up here.'
                  : '$firstName has not spent anything yet. Purchases at the '
                      'tuck shop will show up here.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: List.generate(6, (i) {
        return Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1200.ms,
              color: AppColors.surfaceContainerHighest,
            );
      }),
    );
  }
}