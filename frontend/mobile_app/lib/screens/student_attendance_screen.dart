import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/storage/secure_storage.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';
import 'attendance_take_screen.dart';

/// Phase 6 — student hub for marking attendance.
///
/// The previous version bundled QR scan + liveness + face capture on one
/// page. Phase 6 collapses it: the student picks an active session and
/// jumps straight into [AttendanceTakeScreen], which does camera + geo +
/// device + face in one go.
///
/// The server's /api/v1/attendance/verify is the single authority on
/// device binding, geofence, mock-location and face match.
class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  static const _storage = FlutterSecureStorage();

  bool _loading = true;
  String _errorMessage = '';
  List<_ActiveSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final jwt = await _storage.read(key: 'jwt_token');
      final client = ApiClient(
        baseUrl: baseUrl,
        accessTokenProvider: () async => jwt,
      );
      final body = await client.get('${Endpoints.apiPrefix}/sessions/active');
      final list = (body is Map && body['sessions'] is List)
          ? body['sessions'] as List
          : <dynamic>[];
      _sessions = list
          .whereType<Map>()
          .map((m) => _ActiveSession.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (e) {
      _errorMessage = 'Could not load sessions.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openTakeScreen(_ActiveSession session) async {
    final baseUrl = await AppConfig.getBaseUrl();
    final jwt = await SecureStorage.instance.readAccessToken();
    final client = ApiClient(
      baseUrl: baseUrl,
      accessTokenProvider: () async => jwt,
    );
    final marked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttendanceTakeScreen(
          sessionId: session.id,
          apiClient: client,
        ),
      ),
    );
    if (marked == true && mounted) {
      await _loadActiveSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GradientAppBar(
        title: 'Mark Attendance',
        gradient: AppGradients.primaryDeep,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveSessions,
        color: AppColors.primary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load sessions',
          subtitle: _errorMessage,
          actionLabel: 'Retry',
          onAction: _loadActiveSessions,
        ),
      );
    }
    if (_sessions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'No active sessions',
            subtitle: 'No teacher has opened an attendance session right now. '
                'Pull down to refresh.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            onTap: () => _openTakeScreen(session),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: const Icon(Icons.fact_check_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        session.teacherName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StatusChip(
                        label: 'Live · ends ${session.endsAtLabel}',
                        background: AppColors.success,
                        foreground: Colors.white,
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveSession {
  final String id;
  final String courseName;
  final String teacherName;
  final DateTime endsAt;

  const _ActiveSession({
    required this.id,
    required this.courseName,
    required this.teacherName,
    required this.endsAt,
  });

  String get endsAtLabel {
    final local = endsAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  factory _ActiveSession.fromJson(Map<String, dynamic> json) {
    DateTime ends;
    final raw = json['endsAt'];
    if (raw is String) {
      ends = DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    } else {
      ends = DateTime.now();
    }
    return _ActiveSession(
      id: (json['id'] ?? json['sessionId'] ?? '').toString(),
      courseName: (json['courseName'] ?? json['course'] ?? 'Attendance session')
          .toString(),
      teacherName:
          (json['teacherName'] ?? json['teacher'] ?? 'Teacher').toString(),
      endsAt: ends,
    );
  }
}
