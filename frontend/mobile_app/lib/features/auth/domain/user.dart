import 'role.dart';

/// User entity — server-authoritative. Mirrors the backend's public payload.
class User {
  final String id;
  final AppRole role;
  final String fullName;
  final String email;

  // Student-only
  final String? registrationNo;
  final String? department;
  final String? session;

  // Teacher-only
  final String? teacherId;
  final String? designation;

  const User({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.registrationNo,
    this.department,
    this.session,
    this.teacherId,
    this.designation,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    final role = AppRole.fromWire(j['role'] as String?);
    return User(
      id: j['id'] as String,
      role: role,
      fullName: (j['fullName'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      registrationNo: j['registrationNo'] as String?,
      department: j['department'] as String?,
      session: j['session'] as String?,
      teacherId: j['teacherId'] as String?,
      designation: j['designation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.wireValue,
        'fullName': fullName,
        'email': email,
        if (registrationNo != null) 'registrationNo': registrationNo,
        if (department != null) 'department': department,
        if (session != null) 'session': session,
        if (teacherId != null) 'teacherId': teacherId,
        if (designation != null) 'designation': designation,
      };

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
