// Spending controls for one child: the daily limit with today's spend
// against it, the card's state with Block / Unblock, and the history of
// every change (kept by the server: who, what, from, to, when).
//
// Changing the limit or the card asks for the PIN first; the server
// checks it, and a wrong PIN shows the server's message. Lost or stolen
// stays on the child's wallet screen: that retires the card for good.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/load_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pin_confirm_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/spending_controls.dart';
import '../../../data/models/student.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/wallet_service.dart';

class ControlsScreen extends StatefulWidget {
  final Student student;

  const ControlsScreen({super.key, required this.student});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  final _service = WalletService();
  final _ugx = NumberFormat('#,##0', 'en_US');
  final _when = DateFormat('d MMM, HH:mm');

  SpendingControls? _controls;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _service.getControls(widget.student.id);
      if (!mounted) return;
      setState(() {
        _controls = c;
        _error = null;
      });
    } on SessionExpiredException {
      // The router returns to login.
    } catch (e) {
      if (mounted) setState(() => _error = loadErrorText(e));
    }
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(String action, Future<void> Function(String pin) change,
      String done) async {
    final pin = await askForPin(context, action: action);
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await change(pin);
      _say(done);
      await _load();
    } on SessionExpiredException {
      return;
    } catch (e) {
      _say(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _changeLimit(SpendingControls c) async {
    final controller = TextEditingController(text: c.dailyLimit.toString());
    String? fieldError;
    final value = await showDialog<int>(
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
                decoration: InputDecoration(prefixText: 'UGX ', errorText: fieldError),
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
                final v = int.tryParse(controller.text.trim());
                if (v == null || v < c.limitMin || v > c.limitMax) {
                  setDialogState(() => fieldError =
                      'Enter an amount from UGX ${_ugx.format(c.limitMin)} '
                      'to ${_ugx.format(c.limitMax)}.');
                  return;
                }
                Navigator.of(dialogContext).pop(v);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value == c.dailyLimit) return;
    await _run(
      'set the daily limit to UGX ${_ugx.format(value)}',
      (pin) => _service.setDailyLimit(
          studentId: widget.student.id, dailyLimit: value, pin: pin),
      'Daily limit set to UGX ${_ugx.format(value)}.',
    );
  }

  Future<void> _setBlocked(bool blocked) => _run(
        blocked ? 'block ${widget.student.name}\'s card' : 'unblock the card',
        (pin) => _service.setCardBlocked(
            studentId: widget.student.id, blocked: blocked, pin: pin),
        blocked ? 'Card blocked. It will be refused at the till.' : 'Card unblocked.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('${widget.student.name} · Controls')),
      body: _controls == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(AppTheme.marginMobile),
                  child: LoadFailed(
                    title: 'Could not load the controls',
                    message: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  ),
                ))
          : RefreshIndicator(onRefresh: _load, child: _body(_controls!)),
    );
  }

  Widget _section(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.level1CardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _body(SpendingControls c) {
    final over = c.spentToday >= c.dailyLimit;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        _section([
          Text('Daily limit', style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spaceXs),
          Text('UGX ${_ugx.format(c.dailyLimit)}', style: AppTheme.headlineLgMobile),
          const SizedBox(height: AppTheme.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: c.spentFraction,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: over ? AppColors.error : AppColors.accent,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Spent today: UGX ${_ugx.format(c.spentToday)} · '
            '${over ? 'limit reached' : 'UGX ${_ugx.format(c.remainingToday)} left'}',
            style: AppTheme.bodySm,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _changeLimit(c),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Change limit'),
          ),
        ]),
        const SizedBox(height: AppTheme.spaceLg),
        _section([
          Text('Card', style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spaceXs),
          Row(
            children: [
              Icon(_cardIcon(c.card.state), color: _cardColor(c.card.state)),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(_cardLabel(c.card),
                    style: AppTheme.bodyLg.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(_cardNote(c.card.state), style: AppTheme.bodySm),
          if (c.card.canBlock || c.card.canUnblock) ...[
            const SizedBox(height: AppTheme.spaceMd),
            c.card.canBlock
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: _busy ? null : () => _setBlocked(true),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Block card'),
                  )
                : ElevatedButton.icon(
                    onPressed: _busy ? null : () => _setBlocked(false),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Unblock card'),
                  ),
          ],
        ]),
        const SizedBox(height: AppTheme.spaceLg),
        Text('Changes', style: AppTheme.headlineMd),
        const SizedBox(height: AppTheme.spaceSm),
        if (c.history.isEmpty)
          Text('No changes yet.', style: AppTheme.bodySm)
        else
          for (final h in c.history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.describe(), style: AppTheme.bodyMd),
                  Text(_when.format(h.at.toLocal()),
                      style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
      ],
    );
  }

  String _cardLabel(CardControl card) {
    final digits = card.lastDigits == null ? '' : ' ···${card.lastDigits}';
    return switch (card.state) {
      'active' => 'Working$digits',
      'blocked' => 'Blocked$digits',
      'lost' => 'Reported lost$digits',
      'stolen' => 'Reported stolen$digits',
      'replaced' => 'Replaced$digits',
      'none' => 'No card yet',
      _ => 'Not usable$digits',
    };
  }

  String _cardNote(String state) => switch (state) {
        'active' => 'Payments at the tuck shop work. Block it to pause them; '
            'you can unblock it later.',
        'blocked' => 'Refused at the till until you unblock it. The balance is kept.',
        'lost' || 'stolen' => 'This card can never be used again. Buy a '
            'replacement, or ask the school.',
        'none' => 'The school links the card when they hand it over.',
        _ => 'Ask the school office about a card.',
      };

  IconData _cardIcon(String state) => switch (state) {
        'active' => Icons.credit_card_rounded,
        'blocked' => Icons.block_rounded,
        _ => Icons.credit_card_off_rounded,
      };

  Color _cardColor(String state) => switch (state) {
        'active' => AppColors.success,
        'blocked' => AppColors.error,
        _ => AppColors.onSurfaceVariant,
      };
}
