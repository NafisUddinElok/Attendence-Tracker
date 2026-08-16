// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';

class TeacherReportScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;

  const TeacherReportScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
  });

  @override
  State<TeacherReportScreen> createState() => _TeacherReportScreenState();
}

class _TeacherReportScreenState extends State<TeacherReportScreen> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  List<dynamic> _enrolledStudents = [];
  int _totalEnrolled = 0;

  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents();
  }

  Future<void> _fetchEnrolledStudents([String query = '']) async {
    setState(() => _isLoading = true);

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/courses/${widget.courseId}/students?search=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _enrolledStudents = data['students'] ?? [];
          _totalEnrolled = data['totalEnrolled'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAttendanceReport() async {
    setState(() => _isExporting = true);
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/course/${widget.courseId}/csv'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final fileName = '${widget.courseCode}_Attendance_Report.csv';
        final file = File('${Directory.systemTemp.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Report saved: ${file.path}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String msg = 'Export failed (${response.statusCode})';
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: '${widget.courseCode} · Report',
        gradient: AppGradients.teacherDeep,
        showBackButton: true,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportAttendanceReport,
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Stats + Search
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientHeroCard(
                  gradient: AppGradients.teacherDeep,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusChip(
                              label: widget.courseCode,
                              background: Colors.white.withValues(alpha: 0.18),
                              foreground: Colors.white,
                              icon: Icons.menu_book_rounded,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              widget.courseTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Course Attendance Report',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '$_totalEnrolled',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Enrolled',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _fetchEnrolledStudents(value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search by Reg No or Name...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _enrolledStudents.isEmpty
                    ? EmptyState(
                        icon: Icons.group_outlined,
                        title: _searchQuery.isEmpty
                            ? 'No students enrolled yet'
                            : 'No matches found',
                        subtitle: _searchQuery.isEmpty
                            ? 'Students will appear here once they enroll in this course.'
                            : 'No students match "$_searchQuery".',
                        accentColor: AppColors.teacherPrimary,
                        actionLabel: _searchQuery.isEmpty
                            ? null
                            : 'Clear Search',
                        onAction: _searchQuery.isEmpty
                            ? null
                            : () {
                                _searchQuery = '';
                                _fetchEnrolledStudents();
                              },
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchEnrolledStudents(_searchQuery),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          itemCount: _enrolledStudents.length,
                          itemBuilder: (context, index) {
                            final student = _enrolledStudents[index];
                            final regNo =
                                student['registration_no'] ?? 'N/A';
                            final name = student['full_name'] ?? 'Unnamed';
                            final dept = student['department'] ?? 'SUST';

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.teacher,
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.sm),
                                      ),
                                      child: Center(
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'S',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$regNo · $dept',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusChip(
                                      label: 'Enrolled',
                                      background:
                                          AppColors.info.withValues(alpha: 0.12),
                                      foreground: AppColors.info,
                                      icon: Icons.verified_user_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}