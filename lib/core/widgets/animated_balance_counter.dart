// Reusable count-up animation for wallet balances.
// Animates from 0 to the target value whenever it first appears.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedBalanceCounter extends StatelessWidget {
  final double balance;
  final TextStyle? style;
  final Duration duration;

  const AnimatedBalanceCounter({
    super.key,
    required this.balance,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0', 'en_US');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: balance),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          'UGX ${formatter.format(value)}',
          style: style,
        );
      },
    );
  }
}