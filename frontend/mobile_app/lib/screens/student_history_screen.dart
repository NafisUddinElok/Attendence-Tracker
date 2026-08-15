import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }

  Future<void> _fetchAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/history/student'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _historyList = data['attendanceHistory'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load records (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, List<dynamic>> _groupByCourse() {
    final Map<String, List<dynamic>> grouped = {};
    for (var item in _historyList) {
      final code = item['course_code'] ?? 'GENERAL';
      grouped.putIfAbsent(code, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedCourses = _groupByCourse();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'My Attendance History',
        gradient: AppGradients.primaryDeep,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 48),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_errorMessage!,
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.textSecondary)),
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          onPressed: _fetchAttendanceHistory,
                        ),
                      ],
                    ),
                  )
                : _historyList.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No attendance records yet',
                        subtitle:
                            'Attend a class to see your timeline and per-course progress here.',
                        accentColor: AppColors.primary,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _buildOverallHeader(
                              _historyList.length, groupedCourses.length),
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(
                              title: 'Course-wise Performance',
                              icon: Icons.bar_chart_rounded),
                          const SizedBox(height: AppSpacing.sm),
                          ...groupedCourses.entries.map((entry) {
                            const int estimatedTotalClasses = 20;
                            final attendedCount = entry.value.length;
                            final percentage = (attendedCount /
                                    estimatedTotalClasses) *
                                100;
                            return _buildCourseCard(
                              courseCode: entry.key,
                              courseTitle:
                                  entry.value.first['course_title'] ?? '',
                              attended: attendedCount,
                              total: estimatedTotalClasses,
                              percentage: percentage.clamp(0.0, 100.0),
                            );
                          }),
                          const SizedBox(height: AppSpacing.lg),
                          const SectionHeader(
                              title: 'Recent Check-in Timeline',
                              icon: Icons.timeline_rounded),
                          const SizedBox(height: AppSpacing.sm),
                          ..._historyList.map((item) => _buildTimelineTile(item)),
                        ],
                      ),
      ),
    );
  }

  Widget _buildOverallHeader(int totalPresent, int totalCourses) {
    return GradientHeroCard(
      gradient: AppGradients.primaryDeep,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$totalPresent',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Total Attended',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Column(
            children: [
              Text(
                '$totalCourses',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Active Courses',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required String courseCode,
    required String courseTitle,
    required int attended,
    required int total,
    required double percentage,
  }) {
    Color statusColor;
    Color statusBg;
    String statusBadge;

    if (percentage >= 75.0) {
      statusColor = AppColors.success;
      statusBg = AppColors.successLight;
      statusBadge = 'Collegiate · Eligible';
    } else if (percentage >= 60.0) {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.12);
      statusBadge = 'Non-Collegiate · Fine';
    } else {
      statusColor = AppColors.danger;
      statusBg = AppColors.dangerLight;
      statusBadge = 'Discollegiate · Ineligible';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusChip(
                  label: courseCode,
                  background: AppColors.primaryLight,
                  foreground: AppColors.primary,
                  icon: Icons.menu_book_rounded,
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              courseTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: percentage / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: statusColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$attended / $total Classes',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTile(dynamic item) {
    final DateTime markedAt =
        DateTime.tryParse(item['marked_at'] ?? '') ?? DateTime.now();
    final formattedTime =
        '${markedAt.hour.toString().padLeft(2, '0')}:${markedAt.minute.toString().padLeft(2, '0')}';
    final formattedDate =
        '${markedAt.day.toString().padLeft(2, '0')}/${markedAt.month.toString().padLeft(2, '0')}/${markedAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['session_title'] ?? 'Regular Class',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['course_code']} · $formattedDate · $formattedTime',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Text(
                'PRESENT',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}