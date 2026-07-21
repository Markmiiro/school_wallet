// NFC Card View / Assign screen. Lets a parent tap a physical NFC card
// to read its UID, then link it to a student via the backend.
//
// Status limitation (known): the backend has no confirmed GET endpoint
// that returns a student's current NFC status, so on a fresh load we
// can't show whether a card was previously assigned. We only reflect
// the assignment made in this session. (Pinned backend item #4.)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/student.dart';
import '../../../data/services/nfc_service.dart';
import '../../../data/services/wallet_service.dart';

enum NfcStage { idle, scanning, assigning, assigned, error }

class NfcCardViewScreen extends StatefulWidget {
  final Student student;

  const NfcCardViewScreen({super.key, required this.student});

  @override
  State<NfcCardViewScreen> createState() => _NfcCardViewScreenState();
}

class _NfcCardViewScreenState extends State<NfcCardViewScreen> {
  final NfcService _nfcService = NfcService();
  final WalletService _walletService = WalletService();

  NfcStage _stage = NfcStage.idle;
  String? _uid;
  String? _error;

  @override
  void dispose() {
    _nfcService.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _stage = NfcStage.scanning;
      _error = null;
      _uid = null;
    });

    try {
      final uid = await _nfcService.readCardUid();
      if (!mounted) return;

      setState(() {
        _uid = uid;
        _stage = NfcStage.assigning;
      });

      await _walletService.assignNfc(
        studentId: widget.student.id,
        tagUid: uid,
      );

      if (!mounted) return;
      setState(() => _stage = NfcStage.assigned);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = NfcStage.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('NFC Card · ${widget.student.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.marginMobile),
          child: Center(child: _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case NfcStage.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contactless_rounded,
                size: 96, color: AppColors.primary),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Assign an NFC Card', style: AppTheme.headlineMd),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Tap "Start Scan", then hold the NFC card against the back '
              'of your phone to link it to ${widget.student.name}.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.nfc_rounded),
                label: const Text('Start Scan'),
              ),
            ),
          ],
        );

      case NfcStage.scanning:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contactless_rounded,
                    size: 96, color: AppColors.primary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn()
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 800.ms,
                ),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Hold card to phone…', style: AppTheme.headlineMd),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Keep the card still against the back of the device.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            TextButton(
              onPressed: () async {
                await _nfcService.cancel();
                if (mounted) setState(() => _stage = NfcStage.idle);
              },
              child: const Text('Cancel'),
            ),
          ],
        );

      case NfcStage.assigning:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Linking card…', style: AppTheme.headlineMd),
            if (_uid != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text('UID: $_uid', style: AppTheme.labelMono),
            ],
          ],
        );

      case NfcStage.assigned:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 96)
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Card Assigned', style: AppTheme.headlineMd)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              '${widget.student.name} can now tap to pay at the tuck shop.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            if (_uid != null) ...[
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
                child: Text('UID: $_uid', style: AppTheme.labelMono),
              ),
            ],
            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        );

      case NfcStage.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 96),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Could Not Assign Card', style: AppTheme.headlineMd),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startScan,
                child: const Text('Try Again'),
              ),
            ),
          ],
        );
    }
  }
}