// Buy-a-Card screen. An interactive, tilting NFC card preview that
// recolors live as the parent picks a color. Colors are limited to the
// 4 approved by Yo Uganda per the USSD registration spec (Blue, Green,
// Yellow, Red). A circular badge slot is reserved on the card for the
// school crest — shown as a placeholder icon until the backend exposes
// per-school badge images (pinned backend item).
//
// The card is bought for a child who already exists (the school or USSD
// registration creates children) and has no working card. The parent
// pays a fixed UGX 25,000 by mobile money through CardService; the
// screen then polls every 3s (up to ~90s) until the order resolves.
// The school hands the card over, and it is linked by its number.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/student.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/card_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'dart:math' as math;

enum BuyCardStage { form, waiting, success, failed }

class CardOption {
  final String label;
  final Color color;
  final Color onColor;
  const CardOption(this.label, this.color, this.onColor);
}

class BuyCardScreen extends StatefulWidget {
  const BuyCardScreen({super.key});

  @override
  State<BuyCardScreen> createState() => _BuyCardScreenState();
}

class _BuyCardScreenState extends State<BuyCardScreen> {
  // The 4 approved card colors, per the Yo Uganda USSD spec.
  static const List<CardOption> _options = [
    CardOption('Blue', AppColors.cardBlue, AppColors.onCardFace),
    CardOption('Green', AppColors.cardGreen, AppColors.onCardFace),
    CardOption('Yellow', AppColors.cardYellow, AppColors.onCardFace),
    CardOption('Red', AppColors.cardRed, AppColors.onCardFace),
  ];

  static const int registrationFee = CardService.cardPriceUgx;

  final CardService _cardService = CardService();
  final _phoneController = TextEditingController();

  int _selected = 0;
  int? _studentId;
  String _network = 'MTN';
  BuyCardStage _stage = BuyCardStage.form;
  String? _error;
  String? _referenceId;
  String _waitingMessage = '';

  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30; // 30 x 3s = 90s

  // Tilt state
  double _tiltX = 0; // rotateY
  double _tiltY = 0; // rotateX
  bool _dragging = false;
  Offset _start = Offset.zero;
  Timer? _idle;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    // The parent usually pays from the number they log in with.
    final phone = context.read<AuthProvider>().currentUser?.phone ?? '';
    if (phone.startsWith('256')) _phoneController.text = phone.substring(3);
    // Opened straight from its address (a reload on the web), nothing
    // has loaded the children yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChildren());
    // Gentle ambient float when not being dragged.
    _idle = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_dragging && mounted) {
        setState(() {
          _t += 0.04;
          _tiltX = (0.14) * (1) * (100) * 0.0 + 8 * _sin(_t);
          _tiltY = 5 * _cos(_t * 0.7);
        });
      }
    });
  }

  Future<void> _loadChildren() async {
    final wallet = context.read<WalletProvider>();
    final parentId = context.read<AuthProvider>().currentUser?.id;
    if (wallet.hasLoaded || parentId == null) return;
    await wallet.loadForParent(parentId);
  }

  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);

  @override
  void dispose() {
    _idle?.cancel();
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  /// Children who can be bought a card: those without a working one.
  List<Student> _eligible(List<Student> students) =>
      students.where((s) => !s.hasActiveCard).toList();

  Future<void> _handleSubmit(Student student, CardOption option) async {
    final phone = CardService.normalizePhone(_phoneController.text);
    if (phone == null) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }

    setState(() {
      _error = null;
      _stage = BuyCardStage.waiting;
      _waitingMessage = 'Sending payment request…';
    });

    try {
      final result = await _cardService.buyCard(
        studentId: student.id,
        cardColor: option.label,
        phoneNumber: phone,
        network: _network,
      );
      if (!mounted) return;
      _referenceId = result.referenceId;
      setState(() => _waitingMessage = result.message);
      _startPolling();
    } on SessionExpiredException {
      // The router is already on its way back to the login screen.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = BuyCardStage.failed;
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
        final status = await _cardService.checkStatus(_referenceId!);
        if (status == 'paid' || status == 'fulfilled') {
          timer.cancel();
          if (mounted) setState(() => _stage = BuyCardStage.success);
          return;
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _stage = BuyCardStage.failed;
              _error = 'Payment failed or was rejected.';
            });
          }
          return;
        }
      } catch (_) {
        // Ignore individual poll errors; keep trying until timeout.
      }

      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _stage = BuyCardStage.failed;
            _error =
                'Timed out waiting for approval. If you approved on your '
                'phone, the payment is still recorded for the school and '
                'you will not be charged twice.';
          });
        }
      }
    });
  }

  void _onPanStart(DragStartDetails d) {
    _dragging = true;
    _start = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final dx = d.localPosition.dx - _start.dx;
    final dy = d.localPosition.dy - _start.dy;
    setState(() {
      _tiltX = (dx / 4).clamp(-25.0, 25.0);
      _tiltY = (-dy / 4).clamp(-25.0, 25.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging = false;
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final option = _options[_selected];
    final wallet = context.watch<WalletProvider>();
    final eligible = _eligible(wallet.students);
    final student = eligible.isEmpty
        ? null
        : eligible.firstWhere((s) => s.id == _studentId,
            orElse: () => eligible.first);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Buy a Card')),
      body: SafeArea(
        child: switch (_stage) {
          BuyCardStage.form =>
            _buildForm(option, wallet, eligible, student),
          BuyCardStage.waiting => _buildWaiting(),
          BuyCardStage.success => _buildSuccess(option, student),
          BuyCardStage.failed => _buildFailed(),
        },
      ),
    );
  }

  Widget _buildForm(
    CardOption option,
    WalletProvider wallet,
    List<Student> eligible,
    Student? student,
  ) {
    final students = wallet.students;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      children: [
        Text(
          "Customize your child's tap-to-pay card",
          style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.spaceXl),

        // Interactive card preview
        Center(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_tiltY * 3.1416 / 180)
                ..rotateY(_tiltX * 3.1416 / 180),
              child: _cardFace(option, student),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spaceSm),
        Center(
          child: Text('Drag the card to tilt it',
              style: AppTheme.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
        ),

        const SizedBox(height: AppTheme.spaceXl),

        if (!wallet.hasLoaded)
          wallet.errorMessage != null
              ? LoadFailed(
                  title: 'Could not load your children',
                  message: wallet.errorMessage!,
                  onRetry: _loadChildren,
                )
              : const LoadingBlocks(count: 2)
        else if (student == null)
          _noChildNotice(students.isEmpty)
        else ...[
          if (eligible.length > 1) ...[
            Text('Card for',
                style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceSm),
            DropdownButtonFormField<int>(
              initialValue: student.id,
              items: [
                for (final s in eligible)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (id) => setState(() => _studentId = id),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          Text('Card colour',
              style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: List.generate(_options.length, (i) {
              final o = _options[i];
              final selected = i == _selected;
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spaceMd),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: o.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? o.color : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: o.color.withOpacity(0.4),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                            color: AppColors.onCardFace, size: 18)
                        : null,
                  ),
                ),
              );
            }),
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

          const SizedBox(height: AppTheme.spaceXl),

          // Price row
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.level1CardBorder),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card price',
                        style: AppTheme.bodySm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                    Text(_priceLabel,
                        style: AppTheme.headlineMd
                            .copyWith(color: AppColors.primary, fontSize: 20)),
                  ],
                ),
                const Spacer(),
                Text('Paid by mobile money',
                    style: AppTheme.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Text(_error!,
                style: AppTheme.bodySm.copyWith(color: AppColors.error)),
          ],

          const SizedBox(height: AppTheme.spaceLg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleSubmit(student, option),
              child: Text('Pay $_priceLabel for ${option.label} Card'),
            ),
          ),
        ],
      ],
    );
  }

  String get _priceLabel =>
      'UGX ${registrationFee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  /// Shown instead of the form when there is nobody to buy a card for.
  Widget _noChildNotice(bool noChildren) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Text(
        noChildren
            ? 'A card is bought for a child the school has registered under '
                'your phone number. Ask the school office to register your '
                'child, then come back here.'
            : 'All your children already have a working card. If a card is '
                "lost, report it from the child's wallet and you can buy a "
                'replacement here.',
        style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
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
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
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
              style:
                  AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(CardOption option, Student? student) {
    final name = student?.name ?? 'your child';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 72)
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Card Paid For', style: AppTheme.headlineMd)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              "Collect $name's ${option.label} card from the school. Once "
              "you have it, link it by its number from $name's wallet.",
              textAlign: TextAlign.center,
              style:
                  AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 72),
            const SizedBox(height: AppTheme.spaceLg),
            Text('Card Not Paid For', style: AppTheme.headlineMd),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style:
                  AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
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
                        _stage = BuyCardStage.form;
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
      ),
    );
  }

  Widget _cardFace(CardOption option, Student? student) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 300,
      height: 190,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: option.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: option.color.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top row: brand + NFC
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nuvora',
                  style: AppTheme.bodyMd.copyWith(
                      color: option.onColor, fontWeight: FontWeight.w600)),
              Icon(Icons.contactless_rounded, color: option.onColor, size: 24),
            ],
          ),
          // Chip
          Positioned(
            top: 44,
            left: 0,
            child: Container(
              width: 38,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.cardChip,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // School badge slot (placeholder until backend provides crest)
          Positioned(
            top: 40,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: option.onColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: option.onColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.shield_rounded,
                  color: option.onColor.withOpacity(0.7), size: 22),
            ),
          ),
          // Bottom: name + number
          Positioned(
            bottom: 0,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((student?.name ?? 'CHILD NAME').toUpperCase(),
                    style: AppTheme.bodyMd.copyWith(
                        color: option.onColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(student?.accountNumber ?? '•••• •••• ••••',
                    style: AppTheme.labelMono.copyWith(
                        color: option.onColor.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}