// Top-Up screen. Collects amount + phone + network, initiates a top-up
// via TopUpService, then auto-polls the status every 3s (up to ~90s)
// until it resolves. Shows a "check your phone" waiting state and a
// success animation when the wallet is credited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/topup_service.dart';

enum TopUpStage { form, waiting, success, failed }

class TopUpScreen extends StatefulWidget {
  final int walletId;
  final String studentName;

  const TopUpScreen({
    super.key,
    required this.walletId,
    required this.studentName,
  });

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TopUpService _topUpService = TopUpService();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();

  String _network = 'MTN';
  TopUpStage _stage = TopUpStage.form;
  String? _error;
  String? _referenceId;
  String _waitingMessage = '';

  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30; // 30 x 3s = 90s

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final amountText = _amountController.text.trim();
    final rawPhone = _phoneController.text.trim();

    final amount = int.tryParse(amountText);
    if (amount == null || amount < 500) {
      setState(() => _error = 'Minimum top-up is UGX 500.');
      return;
    }
    if (amount > 5000000) {
      setState(() => _error = 'Maximum top-up is UGX 5,000,000.');
      return;
    }

    // Normalise phone to 256XXXXXXXXX.
    String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '256${phone.substring(1)}';
    } else if (!phone.startsWith('256')) {
      phone = '256$phone';
    }
    if (phone.length != 12) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }

    setState(() {
      _error = null;
      _stage = TopUpStage.waiting;
      _waitingMessage = 'Sending payment request…';
    });

    try {
      final result = await _topUpService.initiateTopUp(
        walletId: widget.walletId,
        amount: amount,
        phoneNumber: phone,
        network: _network,
      );
      _referenceId = result.referenceId;
      setState(() => _waitingMessage = result.message);
      _startPolling();
    } catch (e) {
      setState(() {
        _stage = TopUpStage.failed;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startPolling() {
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;

      if (_referenceId == null) {
        timer.cancel();
        return;
      }

      try {
        final status = await _topUpService.checkStatus(_referenceId!);
        if (status == 'completed') {
          timer.cancel();
          if (mounted) setState(() => _stage = TopUpStage.success);
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _stage = TopUpStage.failed;
              _error = 'Payment failed or was rejected.';
            });
          }
        }
      } catch (_) {
        // Ignore individual poll errors; keep trying until timeout.
      }

      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _stage = TopUpStage.failed;
            _error =
                'Timed out waiting for approval. If you approved on your '
                'phone, your balance will still update shortly.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Top Up · ${widget.studentName}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.marginMobile),
          child: switch (_stage) {
            TopUpStage.form => _buildForm(),
            TopUpStage.waiting => _buildWaiting(),
            TopUpStage.success => _buildSuccess(),
            TopUpStage.failed => _buildFailed(),
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount (UGX)',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'e.g. 10000'),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          Text('Mobile Money Phone',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              prefixText: '+256 ',
              hintText: '700 000 000',
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          Text('Network',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(child: _networkOption('MTN')),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(child: _networkOption('AIRTEL')),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Text(_error!,
                style: AppTheme.bodySm.copyWith(color: AppColors.error)),
          ],

          const SizedBox(height: AppTheme.spaceXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubmit,
              child: const Text('Send Payment Request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkOption(String network) {
    final selected = _network == network;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: () => setState(() => _network = network),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          network,
          style: AppTheme.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Check your phone', style: AppTheme.headlineMd),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            _waitingMessage,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 72)
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Top-Up Successful', style: AppTheme.headlineMd)
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            "${widget.studentName}'s wallet has been credited.",
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: AppTheme.spaceXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // Pop with `true` so the detail screen knows to refresh.
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 72),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Top-Up Not Completed', style: AppTheme.headlineMd),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            _error ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _stage = TopUpStage.form;
                      _error = null;
                      _referenceId = null;
                    });
                  },
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}