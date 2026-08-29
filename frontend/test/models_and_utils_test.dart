import 'package:att_system/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthUser Model Tests', () {
    test('AuthUser serialization & deserialization', () {
      final user = AuthUser(
        token: 'test-jwt-token',
        role: 'STUDENT',
        userId: 'stu-123',
        email: null,
        registrationNo: '2023831018',
        department: 'Software Engineering',
        academicSession: '2023-24',
      );

      final json = user.toJson();
      expect(json['token'], 'test-jwt-token');
      expect(json['role'], 'STUDENT');
      expect(json['registrationNo'], '2023831018');

      final fromJson = AuthUser.fromJson(json);
      expect(fromJson.displayName, '2023831018');
      expect(fromJson.department, 'Software Engineering');
    });

    test('ClassModel parsing with active session', () {
      final json = {
        'id': 'class-1',
        'code': 'SWE301-2324',
        'department': 'Software Engineering',
        'academicSession': '2023-24',
        'semester': '5th',
        'subjectCode': 'SWE-301',
        'subjectName': 'Software Architecture',
        'credits': '3.0',
        'status': 'ACTIVE',
        'studentCount': 60,
        'activeSessionId': 'sess-999',
      };

      final classModel = ClassModel.fromJson(json);
      expect(classModel.hasActiveSession, true);
      expect(classModel.studentCount, 60);
      expect(classModel.credits, 3.0);
    });

    test('AttendanceMatrix calculation parsing', () {
      final json = {
        'classId': 'class-1',
        'subjectCode': 'SWE-301',
        'totalSessions': 5,
        'totalStudents': 60,
        'averageAttendancePct': 85.5,
        'sessions': [
          {'id': 's1', 'startedAt': '2026-08-29T10:00:00Z'}
        ],
        'columnTotals': [52],
        'rows': [
          {
            'registrationNo': '2023831018',
            'cells': ['P'],
            'totalPresent': 1,
            'totalSessions': 1,
            'percentage': 100.0,
          }
        ],
      };

      final matrix = AttendanceMatrix.fromJson(json);
      expect(matrix.totalSessions, 5);
      expect(matrix.totalStudents, 60);
      expect(matrix.averageAttendancePct, 85.5);
      expect(matrix.rows.first.percentage, 100.0);
    });
  });
}
