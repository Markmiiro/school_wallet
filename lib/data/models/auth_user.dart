// AuthUser model — matches the "user" object returned by /auth/login
// and /auth/register.

class AuthUser {
  final int id;
  final String name;
  final String phone;
  final String role;
  final int? schoolId; // nullable — backend returns null until linked to a school

  AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.schoolId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      role: json['role'],
      schoolId: json['school_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'school_id': schoolId,
      };
}