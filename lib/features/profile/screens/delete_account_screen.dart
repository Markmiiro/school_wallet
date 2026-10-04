// Delete account. Shows what will happen — each child's balance and card,
// the total refund and the number it goes to — then needs the PIN and
// the word DELETE before the red button works. On success the server has
// already ended every session, so this logs out locally and the router
// returns to Login.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/load_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/account_closure.dart';
import '../../../data/services/account_service.dart';
import '../../../providers/auth_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  static const confirmWord = 'DELETE';

  static bool canSubmit({required String pin, required String word}) =>
      RegExp(r'^\d{4}$').hasMatch(pin) && word == confirmWord;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _service = AccountService();
  final _pinController = TextEditingController();
  final _wordController = TextEditingController();
  final _ugx = NumberFormat('#,##0', 'en_US');

  late Future<ClosurePreview> _preview;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preview = _service.fetchPreview();
    _pinController.addListener(_refresh);
    _wordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _pinController.dispose();
    _wordController.dispose();
    super.dispose();
  }

  bool get _ready => DeleteAccountScreen.canSubmit(
      pin: _pinController.text, word: _wordController.text);

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await _service.requestClosure(
      pin: _pinController.text,
      confirm: _wordController.text,
    );
    if (result.success) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 10),
      ));
      await auth.logout(); // the router leaves this screen on its own
      return;
    }
    if (!mounted) return;
    _pinController.clear();
    setState(() {
      _sending = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: FutureBuilder<ClosurePreview>(
          future: _preview,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppTheme.marginMobile),
                child: LoadFailed(
                  title: 'Could not load your account details',
                  message: loadErrorText(snap.error!),
                  onRetry: () =>
                      setState(() => _preview = _service.fetchPreview()),
                ),
              );
            }
            return _body(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _body(ClosurePreview p) {
    final pinTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: AppTheme.labelMono.copyWith(fontSize: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: AppColors.outline),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Before you confirm', style: AppTheme.headlineMd),
          const SizedBox(height: AppTheme.spaceMd),
          _card([
            if (p.children.isEmpty)
              Text('No children are linked to this account.',
                  style: AppTheme.bodyMd),
            for (final c in p.children)
              _row(
                c.name,
                'UGX ${_ugx.format(c.balance)}',
                c.hasWorkingCard ? 'Card stops working' : null,
              ),
            if (p.unissuedCardFees > 0)
              _row('Card paid for, not issued',
                  'UGX ${_ugx.format(p.unissuedCardFees)}', null),
            const Divider(height: AppTheme.spaceLg),
            _row('Refund to ${p.refundPhone}',
                'UGX ${_ugx.format(p.refundTotal)}', null,
                strong: true),
          ]),
          const SizedBox(height: AppTheme.spaceLg),
          Text('What happens',
              style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.spaceSm),
          for (final line in p.consequences)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line, style: AppTheme.bodyMd)),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Your PIN',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          Pinput(
            controller: _pinController,
            length: 4,
            obscureText: true,
            obscuringCharacter: '●',
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Type ${DeleteAccountScreen.confirmWord} to confirm',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          TextField(
            controller: _wordController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Text(_error!, style: AppTheme.bodySm.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppTheme.spaceXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
              ),
              onPressed: _ready && !_sending ? _submit : null,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete my account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.level1CardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String amount, String? note, {bool strong = false}) {
    final weight = strong ? FontWeight.w700 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.bodyMd.copyWith(fontWeight: weight)),
                if (note != null)
                  Text(note,
                      style: AppTheme.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(amount, style: AppTheme.bodyMd.copyWith(fontWeight: weight)),
        ],
      ),
    );
  }
}
