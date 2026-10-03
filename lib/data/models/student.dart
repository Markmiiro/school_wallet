// Student model — matches the objects returned by
// GET /students/parent/{parent_id} and GET /students/{id}.

class Student {
  final int id;
  final String name;
  final int schoolId;
  final String? schoolName;

  /// 12-digit number the parent quotes to top up by USSD.
  final String? accountNumber;

  /// "assigned" | "not assigned" | "blocked" | "lost" | "stolen" |
  /// "replaced" | "no card slot". Null if the backend did not send card
  /// details. "blocked" is a pause the parent can undo in Controls.
  final String? cardStatus;
  final String? cardUid;

  Student({
    required this.id,
    required this.name,
    required this.schoolId,
    this.schoolName,
    this.accountNumber,
    this.cardStatus,
    this.cardUid,
  });

  /// True only when a physical card is linked and usable.
  bool get hasActiveCard => cardStatus == 'assigned';

  factory Student.fromJson(Map<String, dynamic> json) {
    final nfc = json['nfc'] as Map<String, dynamic>?;
    return Student(
      id: json['id'] as int,
      name: json['name'] as String,
      schoolId: json['school_id'] as int,
      schoolName: json['school_name'] as String?,
      accountNumber: json['account_number'] as String?,
      cardStatus: nfc?['status'] as String?,
      cardUid: nfc?['tag_uid'] as String?,
    );
  }
}

/// The card status in words, for the child's wallet screen.
String cardStatusLabel(String? status) {
  switch (status) {
    case 'assigned':
      return 'Active';
    case 'not assigned':
    case 'no card slot':
      return 'No card issued yet';
    case 'blocked':
      return 'Blocked';
    case 'lost':
      return 'Blocked — reported lost';
    case 'stolen':
      return 'Blocked — reported stolen';
    case 'replaced':
      return 'Replaced';
    default:
      return 'Unknown';
  }
}

/// A working card or a paused one can be reported lost or stolen.
bool cardCanBeReported(String? status) =>
    status == 'assigned' || status == 'blocked';
