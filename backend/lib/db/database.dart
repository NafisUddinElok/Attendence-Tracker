import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

/// Singleton PostgreSQL connection pool manager.
class Database {
  Database._();
  static Database? _instance;
  static Database get instance => _instance ??= Database._();

  Connection? _connection;

  Future<Connection> get connection async {
    if (_connection != null && _connection!.isOpen) return _connection!;
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final url =
        env['DATABASE_URL'] ??
        Platform.environment['DATABASE_URL'] ??
        'postgresql://localhost:5432/attdb';

    final isLocal = url.contains('localhost') || url.contains('127.0.0.1');

    final endpoint = Endpoint(
      host: _parseHost(url),
      port: _parsePort(url),
      database: _parseDb(url),
      username: _parseUser(url),
      password: _parsePassword(url),
    );

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        sslMode: isLocal ? SslMode.disable : SslMode.require,
      ),
    );
    return _connection!;
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  // ── URL parsing helpers ──────────────────────────────────────────────────
  String _parseHost(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    final match = RegExp(r'@([^:/]+)').firstMatch(url);
    return match?.group(1) ?? 'localhost';
  }

  int _parsePort(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.port > 0) return uri.port;
    } catch (_) {}
    final match = RegExp(r':(\d+)(?:/|$)').firstMatch(url);
    return match != null ? int.parse(match.group(1)!) : 5432;
  }

  String _parseDb(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
    } catch (_) {}
    final match = RegExp(r'/([^/?]+)(?:\?|$)').firstMatch(url);
    return match?.group(1) ?? 'postgres';
  }

  String? _parseUser(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.userInfo.isNotEmpty) return Uri.decodeComponent(uri.userInfo.split(':').first);
    } catch (_) {}
    final match = RegExp(r'://([^:]+):').firstMatch(url);
    return match?.group(1);
  }

  String? _parsePassword(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.userInfo.contains(':')) {
        final parts = uri.userInfo.split(':');
        return Uri.decodeComponent(parts.sublist(1).join(':'));
      }
    } catch (_) {}
    final match = RegExp(r'://[^:]+:([^@]+)@').firstMatch(url);
    return match?.group(1);
  }
}
