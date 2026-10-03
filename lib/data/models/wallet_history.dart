// WalletHistory model — matches the response from
// GET /wallets/{student_id}/history?limit=20

/// The backend stores timestamps in UTC and sends them with no zone
/// marker ("2026-10-01T09:30:00"). DateTime.parse would read that as
/// device-local time, showing every transaction three hours early in
/// Kampala. Treat an unmarked time as UTC, then convert to local.
DateTime parseBackendTime(String raw) {
  final parsed = DateTime.parse(raw);
  if (parsed.isUtc) return parsed.toLocal();
  return DateTime.utc(
    parsed.year, parsed.month, parsed.day,
    parsed.hour, parsed.minute, parsed.second,
    parsed.millisecond, parsed.microsecond,
  ).toLocal();
}

class Transaction {
  final int id;
  final String type; // "topup" | "payment" | "registration"
  final String direction; // "IN" | "OUT"
  final double amount;
  final String status; // "pending" | "completed" | "failed"
  final String? reference;
  final String? description;

  /// The tuck shop, for a purchase. Null for top-ups and on older
  /// backend builds.
  final String? merchant;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.status,
    this.reference,
    this.description,
    this.merchant,
    required this.date,
  });

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  /// Money into the wallet. Type is the source of truth; older backend
  /// builds sent direction with emoji arrows.
  bool get isIn => type == 'topup' || direction.contains('IN');

  /// A sale at the tuck shop.
  bool get isPurchase => type == 'payment';

  /// Taken while the till had no connection and sent later.
  bool get isOffline => description?.startsWith('[OFFLINE]') ?? false;

  /// What the row is called. A purchase is named after the tuck shop:
  /// the till sends the same description ("Tuck shop purchase") for every
  /// sale, so the description alone says nothing. Older backend builds
  /// sent no merchant but did write "NFC payment at <shop>".
  String get title {
    if (isPurchase) {
      if (merchant != null && merchant!.trim().isNotEmpty) return merchant!.trim();
      final at = RegExp(r'^(?:NFC payment|Payment) at (.+)$')
          .firstMatch(description ?? '');
      return at?.group(1) ?? 'Tuck shop purchase';
    }
    if (type == 'topup') return 'Top-up';
    return description ?? 'Card registration';
  }

  /// A second line for a top-up: the parent's own note, or how it was
  /// paid. Null when the description only repeats "Top-up for <child>".
  String? get note {
    final d = description?.trim();
    if (type != 'topup' || d == null || d.isEmpty) return null;
    if (d.startsWith('USSD top-up')) return 'By USSD';
    if (d.startsWith('Top-up for ')) return null;
    return d;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String,
      direction: json['direction'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      reference: json['reference'] as String?,
      description: json['description'] as String?,
      merchant: json['merchant'] as String?,
      date: parseBackendTime(json['date'] as String),
    );
  }
}

class WalletHistory {
  final int studentId;
  final int walletId;
  final double currentBalance;
  final String currency;
  final double totalToppedUp;
  final double totalSpent;
  final int numberOfTransactions;
  final List<Transaction> transactions;

  /// UGX the child may spend per day. Null on older backend builds.
  final int? dailyLimit;

  /// False when the school has deactivated the wallet. Null if unknown.
  final bool? isActive;

  WalletHistory({
    required this.studentId,
    required this.walletId,
    required this.currentBalance,
    required this.currency,
    required this.totalToppedUp,
    required this.totalSpent,
    required this.numberOfTransactions,
    required this.transactions,
    this.dailyLimit,
    this.isActive,
  });

  factory WalletHistory.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    final txList = json['transactions'] as List<dynamic>;

    return WalletHistory(
      studentId: json['student_id'] as int,
      walletId: json['wallet_id'] as int,
      currentBalance: (json['current_balance'] as num).toDouble(),
      currency: json['currency'] as String,
      totalToppedUp: (summary['total_topped_up'] as num).toDouble(),
      totalSpent: (summary['total_spent'] as num).toDouble(),
      numberOfTransactions: summary['number_of_transactions'] as int,
      dailyLimit: (json['daily_limit'] as num?)?.toInt(),
      isActive: json['is_active'] as bool?,
      transactions: txList
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}