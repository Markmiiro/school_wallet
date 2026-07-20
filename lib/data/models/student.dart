// Student model — matches the objects returned by
// GET /students/parent/{parent_id} and GET /students/{id}.

class Student {
  final int id;
  final String name;
  final int schoolId;

  Student({
    required this.id,
    required this.name,
    required this.schoolId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int,
      name: json['name'] as String,
      schoolId: json['school_id'] as int,
    );
  }
}