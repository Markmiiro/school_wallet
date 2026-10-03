// The list of money in and out, shared by the Transactions screen (the
// whole family, or one child) and the child's wallet screen.
//
// Activity is grouped by day under one date header, so a row carries
// only the time. A purchase and a top-up are different rows: a purchase
// shows the tuck shop and a minus amount in ink, a top-up a plus amount
// in teal. The amount and the time sit in a column of their own on the
// right and are never cut; a long tuck shop name wraps to two lines.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

final _ugx = NumberFormat('#,##0', 'en_US');
final _time = DateFormat('h:mm a');

/// One calendar day of activity, newest first.
class ActivityDay {
  final DateTime day; // midnight, device time
  final List<FamilyTransaction> items;

  ActivityDay(this.day, this.items);

  /// What was spent that day: completed purchases only.
  double get spent => items
      .where((i) => i.tx.isPurchase && i.tx.isCompleted)
      .fold(0.0, (sum, i) => sum + i.tx.amount);
}

/// "Today", "Yesterday", "Sat, 26 Sep", or with the year if it differs.
String dayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final gap = DateTime(today.year, today.month, today.day).difference(d).inDays;
  if (gap == 0) return 'Today';
  if (gap == 1) return 'Yesterday';
  return DateFormat(d.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y').format(d);
}

/// Splits a newest-first list into days, keeping the order inside each.
List<ActivityDay> groupByDay(List<FamilyTransaction> items) {
  final days = <ActivityDay>[];
  for (final item in items) {
    final date = item.tx.date;
    final day = DateTime(date.year, date.month, date.day);
    if (days.isEmpty || days.last.day != day) days.add(ActivityDay(day, []));
    days.last.items.add(item);
  }
  return days;
}

/// The family feed, or one child's part of it when [studentId] is given.
List<FamilyTransaction> activityFor(List<FamilyTransaction> items, int? studentId) =>
    studentId == null
        ? items
        : items.where((i) => i.studentId == studentId).toList();

/// Whether any money was actually spent in [items].
bool hasSpent(List<FamilyTransaction> items) =>
    items.any((i) => i.tx.isPurchase && i.tx.isCompleted);

class ActivityFeed extends StatelessWidget {
  final List<FamilyTransaction> items;

  /// Show whose transaction each row is. Off on a single child's view.
  final bool showChild;

  const ActivityFeed({super.key, required this.items, this.showChild = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in groupByDay(items)) ...[
          ActivityDayHeader(day: day),
          for (final item in day.items) ActivityRow(item: item, showChild: showChild),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ],
    );
  }
}

class ActivityDayHeader extends StatelessWidget {
  final ActivityDay day;

  const ActivityDayHeader({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.bodySm.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: AppTheme.spaceSm),
      child: Row(
        children: [
          Expanded(child: Text(dayLabel(day.day), style: style)),
          if (day.spent > 0)
            Text('Spent UGX ${_ugx.format(day.spent)}',
                softWrap: false, style: style.copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  final FamilyTransaction item;
  final bool showChild;

  const ActivityRow({super.key, required this.item, this.showChild = true});

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final isIn = tx.isIn;
    // Only a completed transaction moved money. A pending or failed
    // top-up must not read as "+UGX".
    final settled = tx.isCompleted;
    final tone = !settled
        ? AppColors.onSurfaceVariant
        : (isIn ? AppColors.moneyIn : AppColors.moneyOut);
    final muted = AppTheme.bodySm.copyWith(fontSize: 12, color: AppColors.onSurfaceVariant);

    final icon = tx.isFailed
        ? Icons.close_rounded
        : tx.isPending
            ? Icons.schedule_rounded
            : tx.isPurchase
                ? Icons.storefront_rounded
                : Icons.add_rounded;

    final status = tx.isFailed
        ? 'Failed — no money moved'
        : tx.isPending
            ? 'Pending approval'
            : null;

    // Under the title: whose it was, then anything worth adding.
    final details = [
      if (showChild) item.studentName,
      if (tx.note != null) tx.note!,
      if (tx.isOffline) 'Recorded offline',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A purchase sits on a plain grey disc, a top-up on a teal tint.
          CircleAvatar(
            radius: 18,
            backgroundColor: settled && isIn
                ? AppColors.moneyIn.withValues(alpha: 0.12)
                : AppColors.surfaceContainerHighest,
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: AppTheme.bodyMd.copyWith(fontSize: 15, height: 20 / 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                for (final line in details)
                  Text(line, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (status != null)
                  Text(
                    status,
                    style: muted.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tx.isFailed ? AppColors.error : AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          // Amount and time keep their full width; the title gives way.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${settled ? (isIn ? '+' : '-') : ''}UGX ${_ugx.format(tx.amount)}',
                softWrap: false,
                style: AppTheme.bodyMd.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  color: tone,
                  decoration: tx.isFailed ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                _time.format(tx.date),
                key: ValueKey('activity-time-${tx.id}'),
                softWrap: false,
                style: muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown above a child's activity when it holds no purchase yet.
class NothingSpentNote extends StatelessWidget {
  final String name;

  const NothingSpentNote({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              '$name has not spent anything yet.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
