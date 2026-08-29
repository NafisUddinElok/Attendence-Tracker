import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/classes/:id/report/matrix
/// Returns full attendance matrix: rows=students, cols=sessions, cells=P/A
Future<Response> onRequest(RequestContext context, String id) async {
  final db = await Database.instance.connection;

  // Get all ended/active sessions for this class
  final sessions = await db.execute(
    r"""SELECT id, started_at FROM class_sessions
        WHERE class_id=$1
        ORDER BY started_at ASC""",
    parameters: [id],
  );

  // Get all enrolled students
  final students = await db.execute(
    r"""SELECT u.id, u.registration_no
        FROM enrollments e
        JOIN users u ON u.id = e.student_id
        WHERE e.class_id=$1 AND e.status='ACTIVE'
        ORDER BY u.registration_no ASC""",
    parameters: [id],
  );

  // Get all attendance records for this class
  final records = await db.execute(
    r"SELECT session_id, student_id FROM attendance_records WHERE class_id=$1",
    parameters: [id],
  );

  // Build presence set
  final presentSet = <String>{};
  for (final r in records) {
    presentSet.add('${r[0]}_${r[1]}');
  }

  // Build matrix
  final sessionList = sessions
      .map(
        (s) => {
          'id': s[0],
          'startedAt': s[1]?.toString(),
        },
      )
      .toList();

  int totalPresent = 0;
  int totalCells = 0;

  final rows = students.map((s) {
    final studentId = s[0] as String;
    final regNo = s[1] as String;
    int studentPresent = 0;

    final cells = sessions.map((sess) {
      final sessId = sess[0] as String;
      final present = presentSet.contains('${sessId}_$studentId');
      if (present) studentPresent++;
      totalCells++;
      return present ? 'P' : 'A';
    }).toList();

    totalPresent += studentPresent;
    final pct = sessions.isEmpty
        ? 0.0
        : (studentPresent / sessions.length * 100).roundToDouble();

    return {
      'registrationNo': regNo,
      'cells': cells,
      'totalPresent': studentPresent,
      'totalSessions': sessions.length,
      'percentage': pct,
    };
  }).toList();

  // Column totals
  final columnTotals = List<int>.filled(sessions.length, 0);
  for (final row in rows) {
    final cells = row['cells'] as List<String>;
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == 'P') columnTotals[i]++;
    }
  }

  final avgPct = totalCells == 0
      ? 0.0
      : (totalPresent / totalCells * 100).roundToDouble();

  // Class info
  final classInfo = await db.execute(
    r"SELECT subject_code, subject_name FROM classes WHERE id=$1",
    parameters: [id],
  );

  return Response(
    body: jsonEncode({
      'classId': id,
      'subjectCode': classInfo.isNotEmpty ? classInfo.first[0] : '',
      'subjectName': classInfo.isNotEmpty ? classInfo.first[1] : '',
      'totalSessions': sessions.length,
      'totalStudents': students.length,
      'averageAttendancePct': avgPct,
      'sessions': sessionList,
      'columnTotals': columnTotals,
      'rows': rows,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
