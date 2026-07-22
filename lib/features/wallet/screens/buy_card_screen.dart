// Buy-a-Card screen. An interactive, tilting NFC card preview that
// recolors live as the parent picks a color. Colors are limited to the
// 4 approved by Yo Uganda per the USSD registration spec (Blue, Green,
// Yellow, Red). A circular badge slot is reserved on the card for the
// school crest — shown as a placeholder icon until the backend exposes
// per-school badge images (pinned backend item).
//
// Per the approved USSD flow, registering a child = buying their card
// for a fixed UGX 25,000. The actual paid flow needs backend model
// support (dob/class/card_color) — so "Buy This Card" is presented as
// coming soon for now.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:math' as math;

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
    CardOption('Blue', Color(0xFF185FA5), Colors.white),
    CardOption('Green', Color(0xFF0F6E56), Colors.white),
    CardOption('Yellow', Color(0xFFBA7517), Colors.white),
    CardOption('Red', Color(0xFFA32D2D), Colors.white),
  ];

  static const int registrationFee = 25000;

  int _selected = 0;

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

  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Buy a Card')),
      body: SafeArea(
        child: ListView(
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
                  child: _cardFace(option),
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
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                );
              }),
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
                      Text('UGX ${registrationFee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                          style: AppTheme.headlineMd
                              .copyWith(color: AppColors.primary, fontSize: 20)),
                    ],
                  ),
                  const Spacer(),
                  Text('Includes registration',
                      style: AppTheme.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceLg),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rocket_launch_rounded,
                              size: 40, color: AppColors.primary),
                          const SizedBox(height: AppTheme.spaceMd),
                          Text('Coming soon', style: AppTheme.headlineMd),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text(
                            'Card ordering with mobile money is on the way. '
                            'For now, you can register your child from the '
                            'dashboard.',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMd
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppTheme.spaceLg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Got it'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Text('Buy This ${option.label} Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardFace(CardOption option) {
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
              Text('School Wallet',
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
                color: const Color(0xFFFFC875),
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
                Text('CHILD NAME',
                    style: AppTheme.bodyMd.copyWith(
                        color: option.onColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                // Account number placeholder — real value pending backend
                // (GET /students/{id} doesn't return account_number yet).
                Text('•••• •••• ••••',
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