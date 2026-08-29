import 'package:attendance_backend/db/database.dart';

/// Creates all tables if they don't exist.
Future<void> runMigrations() async {
  final db = await Database.instance.connection;

  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN','TEACHER','STUDENT')),
      email VARCHAR(255) UNIQUE,
      registration_no VARCHAR(50) UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      department VARCHAR(100),
      academic_session VARCHAR(20),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS classes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      code VARCHAR(20) NOT NULL UNIQUE,
      department VARCHAR(100) NOT NULL,
      academic_session VARCHAR(20) NOT NULL,
      semester VARCHAR(20),
      subject_code VARCHAR(50) NOT NULL,
      subject_name VARCHAR(150),
      credits NUMERIC(3,1) DEFAULT 3.0,
      teacher_id UUID NOT NULL REFERENCES users(id),
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ENDED')),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS enrollments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DROPPED')),
      joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (class_id, student_id)
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS class_sessions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      ended_at TIMESTAMP WITH TIME ZONE,
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ENDED')),
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      radius_meters DOUBLE PRECISION NOT NULL DEFAULT 30.0,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS attendance_records (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      session_id UUID NOT NULL REFERENCES class_sessions(id) ON DELETE CASCADE,
      class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      registration_no VARCHAR(50) NOT NULL,
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      distance_meters DOUBLE PRECISION,
      accuracy_meters DOUBLE PRECISION,
      device_install_id VARCHAR(255) NOT NULL,
      scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (session_id, student_id)
    );
  ''');

  print('[Migrations] All tables ready ✓');
}
