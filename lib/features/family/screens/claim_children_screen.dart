// Add the children the school registered under this parent's number.
// The first time, the parent proves the number with a 6-digit SMS code;
// after that, new children are added with one tap. Pops `true` once
// children were added, so the dashboard reloads.

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/family_service.dart';
import '../../../providers/auth_provider.dart';

class ClaimChildrenScreen extends StatefulWidget {
  final FamilyClaimable claimable;

  const ClaimChildrenScreen({super.key, required this.claimable});

  static bool isCodeComplete(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  @override
  State<ClaimChildrenScreen> createState() => _ClaimChildrenScreenState();
}

class _ClaimChildrenScreenState extends State<ClaimChildrenScreen> {
  final _service = FamilyService();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  List<String>? _added;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() => _run(() async {
        await _service.sendCode();
        _codeSent = true;
      });

  Future<void> _claim() => _run(() async {
        final code = widget.claimable.verified ? null : _codeController.text;
        _added = await _service.claim(code);
      });

  @override
  Widget build(BuildContext context) {
    final phone = context.read<AuthProvider>().currentUser?.phone ?? '';
    final count = widget.claimable.count;
    final noun = count == 1 ? 'child' : 'children';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Add your children')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.marginMobile),
          child: _added != null ? _done() : _ask(phone, count, noun),
        ),
      ),
    );
  }

  Widget _ask(String phone, int count, String noun) {
    final verified = widget.claimable.verified;
    final pinTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: AppTheme.labelMono.copyWith(fontSize: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: AppColors.outline),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count $noun registered under your number',
            style: AppTheme.headlineMd),
        const SizedBox(height: AppTheme.spaceSm),
        Text(
          verified
              ? 'Your number is already confirmed. Tap below to add them.'
              : 'Your school registered $count $noun with the phone number '
                  '$phone. To keep children safe, we first check that this '
                  'phone is yours: we will text a 6-digit code to it.',
          style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spaceXl),
        if (!verified && _codeSent) ...[
          Text('Code from the SMS',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          Pinput(
            controller: _codeController,
            length: 6,
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          TextButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Send a new code'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spaceSm),
          Text(_error!, style: AppTheme.bodySm.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: AppTheme.spaceLg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
            ),
            onPressed: _busy
                ? null
                : verified
                    ? _claim
                    : !_codeSent
                        ? _sendCode
                        : ClaimChildrenScreen.isCodeComplete(_codeController.text)
                            ? _claim
                            : null,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(verified
                    ? 'Add them'
                    : !_codeSent
                        ? 'Send code'
                        : 'Confirm and add'),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLg),
        Text(
          'Not your children, or a number is wrong? Ask the school office.',
          style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _done() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 48),
        const SizedBox(height: AppTheme.spaceMd),
        Text('Added to your account', style: AppTheme.headlineMd),
        const SizedBox(height: AppTheme.spaceSm),
        for (final name in _added!)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceXs),
            child: Text(name, style: AppTheme.bodyLg),
          ),
        const SizedBox(height: AppTheme.spaceXl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
