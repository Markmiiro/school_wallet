// A child's spending controls — matches GET /wallets/{id}/controls
// (app/routes/wallets.py): the daily limit, today's spend against it
// (Kampala day), the card's state, and the history of changes.

import 'package:intl/intl.dart';

final _ugx = NumberFormat('#,##0', 'en_US');

class CardControl {
  /// active | blocked | lost | stolen | replaced | closed | none
  final String state;
  final String? lastDigits;
  final bool canBlock;
  final bool canUnblock;

  CardControl({
    required this.state,
    required this.lastDigits,
    required this.canBlock,
    required this.canUnblock,
  });

  /// The same state in the words the student list uses (Student.cardStatus).
  String get studentStatus => switch (state) {
        'active' => 'assigned',
        'none' => 'not assigned',
        _ => state,
      };

  factory CardControl.fromJson(Map<String, dynamic> json) => CardControl(
        state: json['state'] as String,
        lastDigits: json['last_digits'] as String?,
        canBlock: json['can_block'] as bool,
        canUnblock: json['can_unblock'] as bool,
      );
}

class ControlChangeEntry {
  final String by; // you | school | parent
  final String control; // daily_limit | card
  final String? from;
  final String? to;
  final DateTime at;

  ControlChangeEntry({
    required this.by,
    required this.control,
    required this.from,
    required this.to,
    required this.at,
  });

  factory ControlChangeEntry.fromJson(Map<String, dynamic> json) =>
      ControlChangeEntry(
        by: json['by'] as String,
        control: json['control'] as String,
        from: json['from'] as String?,
        to: json['to'] as String?,
        at: DateTime.parse(json['at'] as String),
      );

  String get _who => switch (by) {
        'you' => 'You',
        'school' => 'The school',
        _ => 'A parent',
      };

  String _money(String? v) => 'UGX ${_ugx.format(int.tryParse(v ?? '') ?? 0)}';

  String describe() {
    if (control == 'daily_limit') {
      return '$_who changed the daily limit from ${_money(from)} to ${_money(to)}';
    }
    return switch (to) {
      'blocked' => '$_who blocked the card',
      'active' => '$_who unblocked the card',
      'lost' || 'stolen' => '$_who reported the card $to',
      'replaced' => '$_who replaced the card',
      _ => '$_who changed the card from $from to $to',
    };
  }
}

class SpendingControls {
  final int dailyLimit;
  final int spentToday;
  final int remainingToday;
  final int limitMin;
  final int limitMax;
  final CardControl card;
  final List<ControlChangeEntry> history;

  SpendingControls({
    required this.dailyLimit,
    required this.spentToday,
    required this.remainingToday,
    required this.limitMin,
    required this.limitMax,
    required this.card,
    required this.history,
  });

  /// Today's spend as a share of the limit, 0 to 1, for a progress bar.
  double get spentFraction =>
      dailyLimit <= 0 ? 1.0 : (spentToday / dailyLimit).clamp(0.0, 1.0);

  factory SpendingControls.fromJson(Map<String, dynamic> json) => SpendingControls(
        dailyLimit: (json['daily_limit'] as num).toInt(),
        spentToday: (json['spent_today'] as num).toInt(),
        remainingToday: (json['remaining_today'] as num).toInt(),
        limitMin: (json['limit_min'] as num).toInt(),
        limitMax: (json['limit_max'] as num).toInt(),
        card: CardControl.fromJson(json['card'] as Map<String, dynamic>),
        history: (json['history'] as List)
            .map((h) => ControlChangeEntry.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}
