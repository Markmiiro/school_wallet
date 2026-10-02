// Link Card screen. The parent types the number of a card they have in
// hand to link it to a child who already exists. Nothing is created
// here: the school (or USSD registration) creates the child; this only
// attaches a card.
//
// The card number is the card's UID in hex, e.g. 04A21B55. The backend
// accepts it from a parent only when the child has no working card —
// replacing a card that still works is done by the school.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/student.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/wallet_service.dart';

class LinkCardScreen extends StatefulWidget {
  final Student student;

  const LinkCardScreen({super.key, required this.student});

  /// Strips separators and upper-cases, e.g. "04:a2:1b:55" -> "04A21B55".
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();

  /// Null if [raw] is a usable card number, otherwise what is wrong.
  /// Mirrors normalize_uid() in the backend: 4 to 10 bytes of hex.
  static String? validate(String raw) {
    if (raw.trim().isEmpty) return 'Enter the card number.';
    if (RegExp(r'[^0-9a-fA-F\s:\-]').hasMatch(raw)) {
      return 'A card number uses only digits and the letters A to F.';
    }
    final cleaned = normalize(raw);
    if (cleaned.length < 8 || cleaned.length > 20 || cleaned.length.isOdd) {
      return 'That does not look like a full card number. Check it and '
          'try again.';
    }
    return null;
  }

  @override
  State<LinkCardScreen> createState() => _LinkCardScreenState();
}

class _LinkCardScreenState extends State<LinkCardScreen> {
  final WalletService _walletService = WalletService();
  final _controller = TextEditingController();

  bool _isSubmitting = false;
  String? _error;
  String? _linkedNumber;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final problem = LinkCardScreen.validate(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final cardNumber = LinkCardScreen.normalize(_controller.text);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _walletService.assignNfc(
        studentId: widget.student.id,
        tagUid: cardNumber,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _linkedNumber = cardNumber;
      });
    } on SessionExpiredException {
      // The router is already on its way back to the login screen.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Link a card · ${widget.student.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.marginMobile),
          child: _linkedNumber != null ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type the number of the card you were given to link it to '
            '${widget.student.name}.',
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          Text('Card number',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            style: AppTheme.labelMono.copyWith(fontSize: 18),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F:\-\s]')),
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: const InputDecoration(hintText: 'e.g. 04A21B55'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _isSubmitting ? null : _handleSubmit(),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'Digits and the letters A to F. If you cannot find the number, '
            'ask the school office.',
            style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
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
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : const Text('Link card'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 96)
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppTheme.spaceLg),
          Text('Card linked', style: AppTheme.headlineMd)
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            '${widget.student.name} can now tap to pay at the tuck shop.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            ),
            child: Text(_linkedNumber!, style: AppTheme.labelMono),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // Pop with `true` so the wallet screen shows the card as active.
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
