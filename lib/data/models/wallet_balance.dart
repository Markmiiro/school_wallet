// WalletBalance model — matches the response from
// GET /wallets/wallets/{student_id}.

class WalletBalance {
  final int studentId;
  final int walletId;
  final double balance;
  final bool isActive;

  WalletBalance({
    required this.studentId,
    required this.walletId,
    required this.balance,
    required this.isActive,
  });

  factory WalletBalance.fromJson(int studentId, Map<String, dynamic> json) {
    return WalletBalance(
      studentId: studentId,
      walletId: json['wallet_id'] as int,
      balance: (json['balance'] as num).toDouble(),
      isActive: json['is_active'] as bool,
    );
  }
}