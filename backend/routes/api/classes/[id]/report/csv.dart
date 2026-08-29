import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET /api/classes/:id/report/csv
/// Returns raw CSV text for attendance matrix
Future<Response> onRequest(RequestContext context, String id) async {
  final db = await Database.instance.connection;

  final sessions = await db.execute(
    r"SELECT id, started_at FROM class_sessions WHERE class_id=$1 ORDER BY started_at ASC",
    parameters: [id],
  );

  final students = await db.execute(
    r"""SELECT u.id, u.registration_no
        FROM enrollments e
        JOIN users u ON u.id = e.student_id
        WHERE e.class_id=$1 AND e.status='ACTIVE'
        ORDER BY u.registration_no ASC""",
    parameters: [id],
  );

  final records = await db.execute(
    r"SELECT session_id, student_id FROM attendance_records WHERE class_id=$1",
    parameters: [id],
  );

  final presentSet = <String>{};
  for (final r in records) {
    presentSet.add('${r[0]}_${r[1]}');
  }

  final buffer = StringBuffer();

  // Header row
  buffer.write('Registration No');
  for (final s in sessions) {
    final dt = s[1]?.toString() ?? '';
    buffer.write(',$dt');
  }
  buffer.write(',Total Present,Percentage\n');

  // Data rows
  for (final stu in students) {
    final studentId = stu[0] as String;
    final regNo = stu[1] as String;
    int present = 0;

    buffer.write(regNo);
    for (final sess in sessions) {
      final sessId = sess[0] as String;
      final isPresent = presentSet.contains('${sessId}_$studentId');
      if (isPresent) present++;
      buffer.write(',${isPresent ? "P" : "A"}');
    }

    final pct = sessions.isEmpty
        ? '0%'
        : '${(present / sessions.length * 100).round()}%';
    buffer.write(',$present,$pct\n');
  }

  final classInfo = await db.execute(
    r"SELECT subject_code FROM classes WHERE id=$1",
    parameters: [id],
  );
  final code = classInfo.isNotEmpty ? classInfo.first[0] : 'class';
  final filename = '${code}_attendance.csv';

  return Response(
    body: buffer.toString(),
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="$filename"',
    },
  );
}
