// Child Wallet Detail screen. Shows balance (animated count-up) and the
// daily spending limit, the child's account number and card status,
// Top Up / change limit / link a card / report card lost actions, and recent
// transaction history for a single student. Reached by tapping a
// child's card on the Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_balance_counter.dart';
import '../../../data/models/student.dart';
import '../../../data/models/wallet_history.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/wallet_service.dart';
import 'top_up_screen.dart';

class ChildWalletDetailScreen extends StatefulWidget {
  final Student student;

  const ChildWalletDetailScreen({super.key, required this.student});

  @override
  State<ChildWalletDetailScreen> createState() =>
      _ChildWalletDetailScreenState();
}

class _ChildWalletDetailScreenState extends State<ChildWalletDetailScreen> {
  // Limits the backend accepts on PUT /wallets/{id}/limit.
  static const int _minDailyLimit = 500;
  static const int _maxDailyLimit = 5000000;

  final WalletService _walletService = WalletService();
  final NumberFormat _ugx = NumberFormat('#,##0', 'en_US');

  bool _isLoading = true;
  String? _error;
  WalletHistory? _history;

  // Starts from what the dashboard loaded; updated here when the parent
  // blocks the card, so the screen does not show a stale "active".
  late String? _cardStatus = widget.student.cardStatus;

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
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } on SessionExpiredException {
      // The router is already on its way back to the login screen.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editDailyLimit(int? current) async {
    final controller = TextEditingController(text: current?.toString() ?? '');
    String? fieldError;

    final newLimit = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Daily spending limit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The most ${widget.student.name} can spend at the tuck shop '
                'in one day. Payments above it are refused.',
                style: AppTheme.bodySm,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'UGX ',
                  errorText: fieldError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null ||
                    value < _minDailyLimit ||
                    value > _maxDailyLimit) {
                  setDialogState(() => fieldError =
                      'Enter an amount from UGX ${_ugx.format(_minDailyLimit)} '
                      'to ${_ugx.format(_maxDailyLimit)}.');
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (newLimit == null || newLimit == current || !mounted) return;

    try {
      await _walletService.setDailyLimit(
        studentId: widget.student.id,
        dailyLimit: newLimit,
      );
      if (!mounted) return;
      _showMessage('Daily limit set to UGX ${_ugx.format(newLimit)}.');
      _load();
    } on SessionExpiredException {
      // Router handles it.
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reportCard() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this card?'),
        content: Text(
          "${widget.student.name}'s card will stop working straight away "
          'and cannot be switched back on. The money in the wallet is '
          'safe. The school will need to issue a new card.',
          style: AppTheme.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('lost'),
            child: Text('It is lost',
                style: AppTheme.bodySm.copyWith(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('stolen'),
            child: Text('It was stolen',
                style: AppTheme.bodySm.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    try {
      await _walletService.reportCard(
        studentId: widget.student.id,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _cardStatus = reason);
      _showMessage('Card blocked. Ask the school for a replacement.');
    } on SessionExpiredException {
      // Router handles it.
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
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
    final walletActive = history.isActive ?? true;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        if (!walletActive) ...[
          _deactivatedBanner(),
          const SizedBox(height: AppTheme.spaceMd),
        ],

        // Balance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [AppColors.level2Shadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance',
                style: AppTheme.bodySm.copyWith(color: AppColors.onPrimaryContainerMuted),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              AnimatedBalanceCounter(
                balance: history.currentBalance,
                style: AppTheme.displayCurrency.copyWith(color: AppColors.onPrimaryContainer),
              ),
              if (history.dailyLimit != null) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daily limit UGX ${_ugx.format(history.dailyLimit)}',
                        style: AppTheme.bodySm.copyWith(
                            color: AppColors.onPrimaryContainerMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _editDailyLimit(history.dailyLimit),
                      child: Text(
                        'Change',
                        style: AppTheme.bodySm.copyWith(
                          color: AppColors.inversePrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                color: AppColors.moneyIn,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: _summaryTile(
                label: 'Spent',
                value: history.totalSpent,
                color: AppColors.moneyOut,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: AppTheme.spaceLg),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: !walletActive
                ? null
                : () async {
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

        const SizedBox(height: AppTheme.spaceLg),

        _detailsCard().animate().fadeIn(delay: 175.ms),

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

  Widget _deactivatedBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.onErrorContainer),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'This wallet has been deactivated by the school. It cannot be '
              'topped up or spent from. The balance is kept.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  String _cardStatusLabel() {
    switch (_cardStatus) {
      case 'assigned':
        return 'Active';
      case 'not assigned':
      case 'no card slot':
        return 'No card issued yet';
      case 'lost':
        return 'Blocked — reported lost';
      case 'stolen':
        return 'Blocked — reported stolen';
      case 'replaced':
        return 'Replaced';
      default:
        return 'Unknown';
    }
  }

  // School, account number and card status, with the card actions.
  Widget _detailsCard() {
    final student = widget.student;
    final cardActive = _cardStatus == 'assigned';

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
          if (student.schoolName != null) ...[
            _detailRow('School', Text(student.schoolName!, style: AppTheme.bodyMd)),
            const Divider(height: AppTheme.spaceLg),
          ],
          if (student.accountNumber != null) ...[
            _detailRow(
              'Account number',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(student.accountNumber!, style: AppTheme.labelMono),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: student.accountNumber!));
                      _showMessage('Account number copied.');
                    },
                  ),
                ],
              ),
            ),
            Text(
              'Use this number to top up by USSD.',
              style: AppTheme.bodySm.copyWith(fontSize: 12),
            ),
            const Divider(height: AppTheme.spaceLg),
          ],
          _detailRow(
            'Card',
            Text(
              _cardStatusLabel(),
              style: AppTheme.bodyMd.copyWith(
                color: (_cardStatus == 'lost' || _cardStatus == 'stolen')
                    ? AppColors.error
                    : AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          if (cardActive)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _reportCard,
                icon: const Icon(Icons.report_gmailerrorred_rounded),
                label: const Text('Report card lost or stolen'),
              ),
            )
          else
            // Cards are linked by the school when it hands them over: a
            // card number proves nothing about who types it.
            Text(
              (_cardStatus == 'lost' || _cardStatus == 'stolen')
                  ? 'Buy a replacement card, or ask the school for one. The '
                      'school links it when they hand it over, and the balance '
                      'moves to it.'
                  : 'No card linked yet. The school links your child\'s card '
                      'when they hand it over. Ask the school office if it is '
                      'taking long.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, Widget value) {
    return Row(
      children: [
        Text(label,
            style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const Spacer(),
        value,
      ],
    );
  }

  Widget _summaryTile({
    required String label,
    required double value,
    required Color color,
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
          Text(label, style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            'UGX ${_ugx.format(value)}',
            style: AppTheme.headlineMd.copyWith(color: color, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Transaction tx) {
    final isIn = tx.isIn;
    // Only a completed transaction moved money. A pending or failed
    // top-up must not read as "+UGX" in the list.
    final settled = tx.isCompleted;
    final tone = !settled
        ? AppColors.onSurfaceVariant
        : (isIn ? AppColors.moneyIn : AppColors.moneyOut);
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
            backgroundColor: tone.withOpacity(0.12),
            child: Icon(
              tx.isFailed
                  ? Icons.close_rounded
                  : tx.isPending
                      ? Icons.schedule_rounded
                      : isIn
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
              size: 18,
              color: tone,
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
                if (!settled)
                  Text(
                    tx.isFailed ? 'Failed — no money moved' : 'Pending approval',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tx.isFailed
                          ? AppColors.error
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${settled ? (isIn ? '+' : '-') : ''}UGX ${_ugx.format(tx.amount)}',
            style: AppTheme.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
              decoration: tx.isFailed ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
