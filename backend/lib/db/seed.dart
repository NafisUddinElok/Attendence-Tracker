import 'package:bcrypt/bcrypt.dart';

import 'package:attendance_backend/db/database.dart';

/// Seeds the database with demo data if not already seeded.
Future<void> runSeed() async {
  final db = await Database.instance.connection;

  // Check if admin exists already
  final existing = await db.execute(
    "SELECT id FROM users WHERE email = 'admin@example.com' LIMIT 1",
  );
  if (existing.isNotEmpty) {
    print('[Seed] Already seeded, skipping.');
    return;
  }

  // ── 1. Admin ────────────────────────────────────────────────────────────
  final adminHash = BCrypt.hashpw('password', BCrypt.gensalt());
  await db.execute(
    r"INSERT INTO users (role, email, password_hash) VALUES ('ADMIN', 'admin@example.com', $1) RETURNING id",
    parameters: [adminHash],
  );
  print('[Seed] Admin created ✓');

  // ── 2. Teacher ───────────────────────────────────────────────────────────
  final teacherHash = BCrypt.hashpw('password', BCrypt.gensalt());
  final teacherRes = await db.execute(
    r"INSERT INTO users (role, email, password_hash, department) VALUES ('TEACHER', 'teacher@example.com', $1, 'Software Engineering') RETURNING id",
    parameters: [teacherHash],
  );
  final teacherId = teacherRes.first[0] as String;
  print('[Seed] Teacher created ✓');

  // ── 3. Sample Class ──────────────────────────────────────────────────────
  final classRes = await db.execute(
    r"""INSERT INTO classes (code, department, academic_session, semester, subject_code, subject_name, teacher_id, status)
        VALUES ('SWE301-2324', 'Software Engineering', '2023-24', '5th', 'SWE-301', 'Software Architecture', $1, 'ACTIVE')
        RETURNING id""",
    parameters: [teacherId],
  );
  final classId = classRes.first[0] as String;
  print('[Seed] Class SWE-301 created ✓');

  // ── 4. 60 Students ───────────────────────────────────────────────────────
  for (int i = 1; i <= 60; i++) {
    final regNo = '2023831${i.toString().padLeft(3, '0')}';
    final hash = BCrypt.hashpw(regNo, BCrypt.gensalt());
    final studentRes = await db.execute(
      r"""INSERT INTO users (role, registration_no, password_hash, department, academic_session)
          VALUES ('STUDENT', $1, $2, 'Software Engineering', '2023-24')
          RETURNING id""",
      parameters: [regNo, hash],
    );
    final studentId = studentRes.first[0] as String;

    // Auto-enroll into the sample class
    await db.execute(
      r"INSERT INTO enrollments (class_id, student_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      parameters: [classId, studentId],
    );
  }
  print('[Seed] 60 Students created and enrolled ✓');
  print('[Seed] Done! 🎉');
}
