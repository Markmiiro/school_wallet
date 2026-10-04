// "Get started": what is still missing before a child can spend at the
// tuck shop. Three steps, in order: the child is on the account, the
// child has a card, money has gone in. A step is listed only while it is
// still to do, so the panel shrinks as the account fills and is gone
// once nothing is left.
//
// Parents do not create children and do not link cards (the school does
// both), so the first two steps say what to ask the school for, and
// offer the part the parent can do here: add children the school has
// already registered under their number, and buy a card.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/student.dart';
import '../../data/services/card_service.dart';

enum SetupStep { child, card, topUp }

/// The steps still to do, in order. [toppedUp] is null while it is not
/// known whether money has ever gone in; the step is then left out
/// rather than shown to a parent who may have done it.
List<SetupStep> setupStepsLeft({
  required List<Student> students,
  required bool? toppedUp,
}) {
  if (students.isEmpty) return SetupStep.values;
  return [
    if (students.any((s) => s.neverHadCard)) SetupStep.card,
    if (toppedUp == false) SetupStep.topUp,
  ];
}

/// What one step says. [action] is the button's label, or null when
/// there is nothing the parent can do about it here yet.
class StepCopy {
  final String title;
  final String body;
  final String? action;

  const StepCopy(this.title, this.body, [this.action]);
}

/// "Amina", "Amina and Brian", "Amina, Brian and Chris": first names.
String firstNames(Iterable<Student> students) {
  final names = [for (final s in students) s.name.trim().split(RegExp(r'\s+')).first];
  if (names.length < 2) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// [waiting] is how many children the school has registered under this
/// parent's number and who are not on the account yet.
StepCopy childStepCopy({required int waiting, String? phone}) {
  if (waiting > 0) {
    return StepCopy(
      waiting == 1
          ? '1 child is waiting for you'
          : '$waiting children are waiting for you',
      'Your school registered them under your phone number.',
      'Add them',
    );
  }
  return StepCopy(
    'Ask the school to add your number',
    'Your child shows here once the school has your phone number'
        '${phone == null || phone.isEmpty ? '' : ' ($phone)'} on their '
        'records. Ask the school office, then check again.',
    'Check again',
  );
}

/// [paidFor] holds the children whose card is bought and waiting at the
/// school: they are told to collect it, never to pay again.
StepCopy cardStepCopy({
  required List<Student> students,
  Set<int> paidFor = const {},
}) {
  if (students.isEmpty) {
    return const StepCopy(
        'Get a card', 'Your child pays at the tuck shop by tapping it.');
  }
  final without = students.where((s) => s.neverHadCard).toList();
  final toBuy = without.where((s) => !paidFor.contains(s.id)).toList();
  if (toBuy.isEmpty) {
    return StepCopy(
      without.length == 1
          ? 'Collect the card for ${firstNames(without)}'
          : 'Collect the cards for ${firstNames(without)}',
      'Paid for. The school links a card when they hand it over. Ask the '
          'school office if it is taking long.',
    );
  }
  final price = NumberFormat('#,##0', 'en_US').format(CardService.cardPriceUgx);
  return StepCopy(
    'Get ${firstNames(toBuy)} a card',
    'Buy one here for UGX $price, or ask the school for one. The school '
        'links it when they hand it over.',
    'Buy a card',
  );
}

StepCopy topUpStepCopy({required List<Student> students}) {
  if (students.isEmpty) {
    return const StepCopy('Make your first top-up',
        'Add money by mobile money for your child to spend at the tuck shop.');
  }
  return StepCopy(
    'Make your first top-up',
    'Add money by mobile money for ${firstNames(students)} to spend at the '
        'tuck shop.',
    'Top up',
  );
}

class GetStartedPanel extends StatelessWidget {
  final List<SetupStep> steps;
  final List<Student> students;
  final int waiting;
  final String? phone;
  final Set<int> paidFor;

  /// The first step's button is working (checking again with the school).
  final bool busy;

  final VoidCallback onAddChildren;
  final VoidCallback onCheckAgain;
  final VoidCallback onBuyCard;
  final VoidCallback onTopUp;

  const GetStartedPanel({
    super.key,
    required this.steps,
    required this.students,
    required this.onAddChildren,
    required this.onCheckAgain,
    required this.onBuyCard,
    required this.onTopUp,
    this.waiting = 0,
    this.phone,
    this.paidFor = const {},
    this.busy = false,
  });

  StepCopy _copy(SetupStep step) => switch (step) {
        SetupStep.child => childStepCopy(waiting: waiting, phone: phone),
        SetupStep.card => cardStepCopy(students: students, paidFor: paidFor),
        SetupStep.topUp => topUpStepCopy(students: students),
      };

  VoidCallback _action(SetupStep step) => switch (step) {
        SetupStep.child => waiting > 0 ? onAddChildren : onCheckAgain,
        SetupStep.card => onBuyCard,
        SetupStep.topUp => onTopUp,
      };

  static IconData _icon(SetupStep step) => switch (step) {
        SetupStep.child => Icons.school_rounded,
        SetupStep.card => Icons.credit_card_rounded,
        SetupStep.topUp => Icons.add_rounded,
      };

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final muted = AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Get started',
                    style: AppTheme.headlineMd.copyWith(fontSize: 17)),
              ),
              Text(steps.length == 1 ? '1 step left' : '${steps.length} steps left',
                  style: muted),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _next(steps.first),
          for (final step in steps.skip(1)) ...[
            const Divider(height: AppTheme.spaceLg),
            _later(step, muted),
          ],
        ],
      ),
    );
  }

  Widget _disc(SetupStep step, {required bool next}) => CircleAvatar(
        radius: 16,
        backgroundColor: next
            ? AppColors.primaryContainer.withValues(alpha: 0.12)
            : AppColors.surfaceContainerHighest,
        child: Icon(_icon(step),
            size: 18, color: next ? AppColors.primary : AppColors.onSurfaceVariant),
      );

  // The step to do now: what it is, why, and the button.
  Widget _next(SetupStep step) {
    final copy = _copy(step);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _disc(step, next: true),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.title,
                  style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(copy.body,
                  style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              if (copy.action != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: busy ? null : _action(step),
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(copy.action!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // A step that comes after: one line. It can be opened early when the
  // parent is able to do it already (a top-up does not need the card).
  Widget _later(SetupStep step, TextStyle muted) {
    final copy = _copy(step);
    final open = copy.action != null;
    final row = Row(
      children: [
        _disc(step, next: false),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Text(copy.title,
              style: open ? AppTheme.bodyMd : AppTheme.bodyMd.copyWith(color: muted.color)),
        ),
        if (open)
          const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
      ],
    );
    if (!open) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: _action(step),
      child: row,
    );
  }
}
