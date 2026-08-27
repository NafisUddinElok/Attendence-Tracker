class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // admin / teacher / student
  final String? registrationNumber;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.registrationNumber,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      registrationNumber: json['registration_number'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'registration_number': registrationNumber,
      };
}
