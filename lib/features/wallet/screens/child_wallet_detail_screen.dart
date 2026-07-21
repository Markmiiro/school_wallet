// Child Wallet Detail screen. Shows balance (animated count-up),
// summary tiles, Top Up and Manage NFC Card buttons, and recent
// transaction history for a single student. Reached by tapping a
// child's card on the Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../data/models/student.dart';
import '../../../data/models/wallet_history.dart';
import '../../../data/services/wallet_service.dart';
import 'top_up_screen.dart';
import 'nfc_card_view_screen.dart';

class ChildWalletDetailScreen extends StatefulWidget {
  final Student student;

  const ChildWalletDetailScreen({super.key, required this.student});

  @override
  State<ChildWalletDetailScreen> createState() =>
      _ChildWalletDetailScreenState();
}

class _ChildWalletDetailScreenState extends State<ChildWalletDetailScreen> {
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  String? _error;
  WalletHistory? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _walletService.getWalletHistory(widget.student.id);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.student.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
              child: Text(_error!, textAlign: TextAlign.center, style: AppTheme.bodyMd),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final history = _history!;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        // Balance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [AppColors.level2Shadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance',
                style: AppTheme.bodySm.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              AnimatedBalanceCounter(
                balance: history.currentBalance,
                style: AppTheme.displayCurrency.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              // NOTE: daily_limit exists on the Wallet model in the backend
              // (models.py: daily_limit, default 20000 UGX/day) but is not
              // yet returned by any confirmed endpoint response we've seen
              // (/wallets/wallets/{id} and /wallets/{id}/history both omit
              // it). Not displaying a guessed value here — add this back
              // once a confirmed source for it is found.
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: AppTheme.spaceLg),

        // Summary row
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                label: 'Topped Up',
                value: history.totalToppedUp,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _summaryTile(
                label: 'Spent',
                value: history.totalSpent,
                color: AppColors.secondary,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: AppTheme.spaceLg),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final didTopUp = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => TopUpScreen(
                    walletId: history.walletId,
                    studentName: widget.student.name,
                  ),
                ),
              );
              // If the top-up completed, reload this screen's data so
              // the new balance and transaction show up.
              if (didTopUp == true) {
                _load();
              }
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Top Up'),
          ),
        ).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: AppTheme.spaceMd),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      NfcCardViewScreen(student: widget.student),
                ),
              );
            },
            icon: const Icon(Icons.contactless_rounded),
            label: const Text('Manage NFC Card'),
          ),
        ).animate().fadeIn(delay: 175.ms),

        const SizedBox(height: AppTheme.spaceXl),

        Text('Recent Transactions', style: AppTheme.headlineMd)
            .animate()
            .fadeIn(delay: 200.ms),
        const SizedBox(height: AppTheme.spaceMd),

        if (history.transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
            child: Center(
              child: Text(
                'No transactions yet.',
                style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...history.transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;
            return _transactionTile(tx)
                .animate()
                .fadeIn(delay: (250 + index * 60).ms)
                .slideX(begin: 0.05, end: 0);
          }),
      ],
    );
  }

  Widget _summaryTile({
    required String label,
    required double value,
    required Color color,
  }) {
    final formatter = NumberFormat('#,##0', 'en_US');
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
          Text(label, style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            'UGX ${formatter.format(value)}',
            style: AppTheme.headlineMd.copyWith(color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Transaction tx) {
    final isIn = tx.direction == 'IN';
    final formatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('MMM d, h:mm a');

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
            backgroundColor: (isIn ? AppColors.primary : AppColors.secondary)
                .withOpacity(0.12),
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
                ),
                Text(
                  dateFormatter.format(tx.date),
                  style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'}UGX ${formatter.format(tx.amount)}',
            style: AppTheme.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: isIn ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}