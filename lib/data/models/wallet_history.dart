// WalletHistory model — matches the response from
// GET /wallets/{student_id}/history?limit=20

class Transaction {
  final int id;
  final String type; // "topup" | "payment"
  final String direction; // "IN" | "OUT"
  final double amount;
  final String status; // "pending" | "completed" | "failed"
  final String? reference;
  final String? description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.status,
    this.reference,
    this.description,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String,
      direction: json['direction'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      reference: json['reference'] as String?,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
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

  WalletHistory({
    required this.studentId,
    required this.walletId,
    required this.currentBalance,
    required this.currency,
    required this.totalToppedUp,
    required this.totalSpent,
    required this.numberOfTransactions,
    required this.transactions,
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
      transactions: txList
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}