import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:attendance_backend/db/database.dart';

/// GET  /api/admin/classes  — list all classes
/// POST /api/admin/classes  — create new class + auto-enroll students
Future<Response> onRequest(RequestContext context) async {
  final db = await Database.instance.connection;

  if (context.request.method == HttpMethod.get) {
    final rows = await db.execute('''
      SELECT c.id, c.code, c.department, c.academic_session, c.semester,
             c.subject_code, c.subject_name, c.credits, c.status, c.created_at,
             u.email as teacher_email, u.id as teacher_id,
             (SELECT COUNT(*) FROM enrollments e WHERE e.class_id = c.id AND e.status = 'ACTIVE') as student_count
      FROM classes c
      LEFT JOIN users u ON u.id = c.teacher_id
      ORDER BY c.created_at DESC
    ''');

    final classes = rows
        .map(
          (r) => {
            'id': r[0],
            'code': r[1],
            'department': r[2],
            'academicSession': r[3],
            'semester': r[4],
            'subjectCode': r[5],
            'subjectName': r[6],
            'credits': r[7],
            'status': r[8],
            'createdAt': r[9]?.toString(),
            'teacherEmail': r[10],
            'teacherId': r[11],
            'studentCount': r[12],
          },
        )
        .toList();

    return _json(classes);
  }

  if (context.request.method == HttpMethod.post) {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final department = body['department'] as String? ?? '';
    final session = body['academicSession'] as String? ?? '';
    final semester = body['semester'] as String? ?? '';
    final subjectCode = body['subjectCode'] as String? ?? '';
    final subjectName = body['subjectName'] as String? ?? '';
    final teacherId = body['teacherId'] as String? ?? '';

    if ([
      department,
      session,
      subjectCode,
      teacherId,
    ].any((v) => v.trim().isEmpty)) {
      return _json({
        'error':
            'Department, academic session, subject code, and teacher are required.',
      }, 400);
    }

    // Generate unique class code
    final cleanSub = subjectCode
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final cleanSess = session.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    var code = '$cleanSub-$cleanSess';

    // Check if code already exists and make unique if needed
    final checkCode = await db.execute(
      r'SELECT id FROM classes WHERE code = $1',
      parameters: [code],
    );
    if (checkCode.isNotEmpty) {
      code =
          '$code-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    }

    try {
      final result = await db.execute(
        r"""INSERT INTO classes (code, department, academic_session, semester, subject_code, subject_name, teacher_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id""",
        parameters: [
          code,
          department,
          session,
          semester,
          subjectCode,
          subjectName,
          teacherId,
        ],
      );

      final classId = result.first[0] as String;

      // Auto-enroll all matching students
      final enrolled = await db.execute(
        r"""INSERT INTO enrollments (class_id, student_id)
            SELECT $1, id FROM users
            WHERE role = 'STUDENT' AND department = $2 AND academic_session = $3
            ON CONFLICT DO NOTHING""",
        parameters: [classId, department, session],
      );

      return _json({
        'id': classId,
        'code': code,
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'enrolledCount': enrolled.affectedRows,
        'message': 'Class created and students auto-enrolled',
      }, HttpStatus.created);
    } catch (e) {
      return _json({'error': e.toString()}, 500);
    }
  }

  return Response(statusCode: HttpStatus.methodNotAllowed);
}

Response _json(Object data, [int status = 200]) => Response(
  statusCode: status,
  body: jsonEncode(data),
  headers: {'Content-Type': 'application/json'},
);
