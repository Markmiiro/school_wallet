// Reusable count-up animation for wallet balances.
// Animates from 0 to the target value whenever it first appears.
//
// Balances are masked until the viewer taps one (BalancePrivacy): the
// phone may be passed around. Tapping any balance shows or hides them
// all, and the choice is remembered on this device.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/balance_privacy.dart';

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
    final privacy = context.watch<BalancePrivacy>();
    final formatter = NumberFormat('#,##0', 'en_US');
    final text = DefaultTextStyle.of(context).style.merge(style);
    final iconSize = (text.fontSize ?? 16) * 0.6;

    final amount = privacy.visible
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text('UGX ${formatter.format(value)}', style: style);
            },
          )
        : Text(BalancePrivacy.masked, style: style);

    return Semantics(
      button: true,
      label: privacy.visible ? 'Hide balances' : 'Show balances',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: privacy.toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: amount),
            SizedBox(width: iconSize / 2),
            Icon(
              privacy.visible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: iconSize,
              color: text.color?.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
