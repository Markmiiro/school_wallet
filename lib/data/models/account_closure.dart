// What deleting the account will do — matches GET /account/closure/preview
// (app/closures.py on the backend). Shown in full before the PIN step.

class ClosureChild {
  final String name;
  final int balance;
  final bool hasWorkingCard;

  ClosureChild({
    required this.name,
    required this.balance,
    required this.hasWorkingCard,
  });

  factory ClosureChild.fromJson(Map<String, dynamic> json) => ClosureChild(
        name: json['name'] as String,
        balance: (json['balance'] as num).toInt(),
        hasWorkingCard: json['has_working_card'] as bool? ?? false,
      );
}

class ClosurePreview {
  final List<ClosureChild> children;
  final int unissuedCardFees;
  final int refundTotal;
  final String refundPhone;
  final int holdHours;
  final int refundDays;
  final List<String> consequences;

  ClosurePreview({
    required this.children,
    required this.unissuedCardFees,
    required this.refundTotal,
    required this.refundPhone,
    required this.holdHours,
    required this.refundDays,
    required this.consequences,
  });

  factory ClosurePreview.fromJson(Map<String, dynamic> json) => ClosurePreview(
        children: (json['children'] as List)
            .map((c) => ClosureChild.fromJson(c as Map<String, dynamic>))
            .toList(),
        unissuedCardFees: (json['unissued_card_fees'] as num).toInt(),
        refundTotal: (json['refund_total'] as num).toInt(),
        refundPhone: json['refund_phone'] as String,
        holdHours: (json['hold_hours'] as num).toInt(),
        refundDays: (json['refund_days'] as num).toInt(),
        consequences: (json['consequences'] as List).cast<String>(),
      );
}
