/// Application roles. Mirrors the backend's uppercase role strings.
enum AppRole {
  student,
  teacher;

  String get wireValue => switch (this) {
        AppRole.student => 'STUDENT',
        AppRole.teacher => 'TEACHER',
      };

  static AppRole fromWire(String? raw) {
    switch (raw) {
      case 'STUDENT':
        return AppRole.student;
      case 'TEACHER':
        return AppRole.teacher;
      default:
        throw ArgumentError('Unknown role: $raw');
    }
  }
}
