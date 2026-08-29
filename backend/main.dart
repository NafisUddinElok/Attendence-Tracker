import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:attendance_backend/db/migrations.dart';
import 'package:attendance_backend/db/seed.dart';

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  print('[Server] Initializing database & running migrations...');
  try {
    await runMigrations();
    await runSeed();
    print('[Server] Database initialized and seeded successfully.');
  } catch (e, st) {
    print('[Server] Error during database initialization: $e\n$st');
  }
  return serve(handler, ip, port);
}
