// Family Transactions feed. Merges every child's wallet history into
// one newest-first timeline, with a per-child chip on each row so you
// can tell whose transaction it is. Animated in/out totals, staggered
// slide-in rows, and a shimmer skeleton while loading.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
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

    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        // Totals row
        Row(
          children: [
            Expanded(
              child: _totalTile(
                label: 'Total In',
                value: wallet.totalIn,
                color: AppColors.primary,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _totalTile(
                label: 'Total Out',
                value: wallet.totalOut,
                color: AppColors.secondary,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: AppTheme.spaceLg),

        Text('Recent Activity', style: AppTheme.headlineMd)
            .animate()
            .fadeIn(delay: 100.ms),
        const SizedBox(height: AppTheme.spaceMd),

        if (wallet.familyTransactions.isEmpty)
          _emptyState()
        else
          ...wallet.familyTransactions.asMap().entries.map((entry) {
            final index = entry.key;
            final ft = entry.value;
            return _txRow(ft)
                .animate()
                .fadeIn(delay: (index * 55).ms, duration: 350.ms)
                .slideX(begin: 0.08, end: 0);
          }),
      ],
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
              Text(label,
                  style: AppTheme.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AnimatedBalanceCounter(
            balance: value,
            style: AppTheme.headlineMd.copyWith(color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _txRow(FamilyTransaction ft) {
    final tx = ft.tx;
    final isIn = tx.direction == 'IN';
    final amountFmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (isIn ? AppColors.primary : AppColors.secondary).withOpacity(0.12),
            child: Icon(
              isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: isIn ? AppColors.primary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? (isIn ? 'Top-up' : 'Payment'),
                  style: AppTheme.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Per-child chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        ft.studentName,
                        style: AppTheme.bodySm.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFmt.format(tx.date),
                      style: AppTheme.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            '${isIn ? '+' : '-'}UGX ${amountFmt.format(tx.amount)}',
            style: AppTheme.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: isIn ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
            Text('No transactions yet',
                style: AppTheme.headlineMd
                    .copyWith(color: AppColors.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              'Top-ups and tuck-shop payments will show up here.',
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