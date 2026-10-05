// Family Transactions feed. Merges every child's wallet history into
// one newest-first timeline, grouped by day, with a filter per child:
// the parent's real question is what one child spent. Totals follow the
// filter. Rows come from core/widgets/activity_feed.dart.
//
// Before any of that there may be nothing to show, for four different
// reasons, and each says so in its own words: still loading, could not
// load, no child on the account yet, and no activity yet.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/activity_feed.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/student.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'top_up_screen.dart';

class TransactionsScreen extends StatefulWidget {
  /// Switches the shell to the Home tab.
  final VoidCallback? onOpenHome;

  const TransactionsScreen({super.key, this.onOpenHome});

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

  Future<void> _topUp(Student student, int walletId) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TopUpScreen(walletId: walletId, studentName: student.name),
    ));
    if (done != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletProvider>();
    if (auth.currentUser != null) await wallet.loadForParent(auth.currentUser!.id);
    await wallet.loadFamilyTransactions();
  }

  // One padded, always-scrollable page, so pull-to-refresh works even
  // when the page holds a single short message.
  Widget _page(List<Widget> children) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        children: children,
      );

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
    if (!wallet.hasLoaded) {
      if (wallet.errorMessage != null) {
        return _page([
          LoadFailed(
            title: 'Could not load your transactions',
            message: wallet.errorMessage!,
            onRetry: _load,
          ),
        ]);
      }
      return _page([const LoadingBlocks(count: 6)]);
    }

    if (wallet.students.isEmpty) {
      return _page([
        EmptyActivity(
          title: 'Nothing here yet',
          body: 'Top-ups and tuck shop purchases show here once your child '
              'is on your account. Home shows what to do first.',
          actionLabel: widget.onOpenHome == null ? null : 'Go to Home',
          onAction: widget.onOpenHome,
        ),
      ]);
    }

    if (wallet.familyTransactions.isEmpty) {
      if (wallet.isHistoryLoading) {
        return _page([const LoadingBlocks(count: 6)]);
      }
      if (wallet.historyError != null) {
        return _page([
          LoadFailed(
            title: 'Could not load your transactions',
            message: wallet.historyError!,
            onRetry: _load,
          ),
        ]);
      }
    }

    // A child who is no longer in the list falls back to the family.
    final student = wallet.students.where((s) => s.id == _studentId).firstOrNull;
    final studentId = student?.id;
    final items = activityFor(wallet.familyTransactions, studentId);
    final firstName = student?.name.split(' ').first;

    // Totals of nothing are two empty boxes: leave them out until money
    // has moved.
    final hasTotals = items.isNotEmpty ||
        wallet.totalInFor(studentId) > 0 ||
        wallet.totalOutFor(studentId) > 0;

    return _page([
      if (wallet.students.length > 1) ...[
        _childFilter(wallet, studentId),
        const SizedBox(height: AppTheme.spaceMd),
      ],

      if (wallet.historyFailedFor.isNotEmpty) ...[
        _partFailed(wallet.historyFailedFor),
        const SizedBox(height: AppTheme.spaceMd),
      ],

      if (hasTotals) ...[
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
      ],

      if (items.isEmpty)
        _emptyState(wallet, student)
      else ...[
        Text(
          firstName == null ? 'Recent activity' : '$firstName\'s activity',
          style: AppTheme.headlineMd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppTheme.spaceSm),

        // Top-ups but no purchase yet: say so rather than leave the
        // parent wondering whether purchases are missing.
        if (firstName != null && !hasSpent(items) && wallet.totalOutFor(studentId) == 0)
          NothingSpentNote(name: firstName),
        ActivityFeed(items: items, showChild: studentId == null)
            .animate()
            .fadeIn(duration: 350.ms),
      ],
    ]);
  }

  // Some children's history did not come back; the rest is shown.
  Widget _partFailed(List<String> names) {
    final who = names.map((n) => n.split(' ').first).join(', ');
    return Row(
      children: [
        Expanded(
          child: Text('Could not load activity for $who.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ],
    );
  }

  // No activity for the family, or for the chosen child. The way to make
  // some appear is a top-up, so offer it when it is clear whose wallet:
  // the chosen child's, or the only child's.
  Widget _emptyState(WalletProvider wallet, Student? chosen) {
    final target = chosen ?? (wallet.students.length == 1 ? wallet.students.first : null);
    final balance = target == null ? null : wallet.balanceFor(target.id);
    final canTopUp = target != null && balance != null && balance.isActive;
    final copy = emptyActivityCopy(
      firstName: chosen?.name.split(' ').first,
      hasCard: !(chosen?.neverHadCard ?? false),
    );
    return EmptyActivity(
      title: copy.title,
      body: copy.body,
      actionLabel: canTopUp ? 'Top up' : null,
      onAction: canTopUp ? () => _topUp(target, balance.walletId) : null,
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
          // The chosen chip is navy with a white label. A blue fill
          // would put a 14px label on blue, which the book allows for
          // large text only.
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surfaceContainerLowest,
          side: BorderSide(
            color: on ? AppColors.primary : AppColors.level1CardBorder,
          ),
          labelStyle: AppTheme.bodySm.copyWith(
            fontWeight: FontWeight.w600,
            color: on ? AppColors.onPrimary : AppColors.onSurface,
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
}
