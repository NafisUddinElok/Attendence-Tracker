/// Auto-calculates academic session from a registration number.
/// e.g., "2023831018" → "2023-24"
String parseSession(String registrationNo) {
  if (registrationNo.length < 4) return 'Unknown';
  final year = int.tryParse(registrationNo.substring(0, 4)) ?? 0;
  final next = (year + 1) % 100;
  return '$year-${next.toString().padLeft(2, '0')}';
}

/// Maps department code (digits 4–6 of reg no) to department name.
/// e.g., "2023831018" → digits 4-6 = "831" → "Software Engineering"
String parseDepartment(String registrationNo) {
  if (registrationNo.length < 7) return 'Unknown';
  final code = registrationNo.substring(4, 7);
  return _departmentMap[code] ?? 'Unknown ($code)';
}

const _departmentMap = {
  '831': 'Software Engineering',
  '331': 'Computer Science & Engineering',
  '131': 'Electrical & Electronic Engineering',
  '231': 'Civil Engineering',
  '431': 'Mechanical Engineering',
  '531': 'Chemical Engineering',
  '631': 'Industrial & Production Engineering',
  '731': 'Architecture',
};
