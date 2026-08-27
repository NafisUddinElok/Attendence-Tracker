class SessionModel {
  final int id;
  final int courseId;
  final String sessionDate;
  final String status;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  SessionModel({
    required this.id,
    required this.courseId,
    required this.sessionDate,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      courseId: json['course_id'],
      sessionDate: json['session_date'] ?? '',
      status: json['status'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: json['radius_meters'] ?? 100,
    );
  }
}
