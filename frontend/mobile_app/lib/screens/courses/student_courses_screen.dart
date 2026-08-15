import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/app_config.dart';
import '../student_attendance_screen.dart';
import '../../theme/app_theme.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allCourses = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/courses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _allCourses = data['courses'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load courses (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollCourse(String courseId, String courseCode) async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/courses/enroll'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'courseId': courseId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully enrolled in $courseCode!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCourses();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Enrollment failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _unenrollCourse(String courseId, String courseCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text('Drop $courseCode?'),
        content: const Text(
            'Are you sure you want to drop this course? Your attendance logs will remain stored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Drop Course',
            icon: Icons.delete_outline,
            color: AppColors.danger,
            height: 42,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/courses/unenroll/$courseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unenrolled from $courseCode successfully.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCourses();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allCourses.where((c) {
      final code = (c['course_code'] ?? '').toString().toLowerCase();
      final title = (c['title'] ?? '').toString().toLowerCase();
      final teacher = (c['teacher_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return code.contains(q) || title.contains(q) || teacher.contains(q);
    }).toList();

    final enrolledCourses =
        filtered.where((c) => c['is_enrolled'] == true).toList();
    final availableCourses =
        filtered.where((c) => c['is_enrolled'] == false).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'Course Registry',
        gradient: AppGradients.primaryDeep,
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Enrolled (${enrolledCourses.length})'),
            Tab(text: 'Available (${availableCourses.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by code, title, or instructor...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!,
                                style: const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: AppSpacing.sm),
                            PrimaryButton(
                              label: 'Retry',
                              icon: Icons.refresh,
                              onPressed: _fetchCourses,
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCourseList(enrolledCourses,
                              isEnrolledTab: true),
                          _buildCourseList(availableCourses,
                              isEnrolledTab: false),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(List<dynamic> courses,
      {required bool isEnrolledTab}) {
    if (courses.isEmpty) {
      return EmptyState(
        icon: isEnrolledTab ? Icons.school_outlined : Icons.search_off_rounded,
        title: isEnrolledTab
            ? 'No enrolled courses yet'
            : 'No matching courses available',
        subtitle: isEnrolledTab
            ? 'Switch to the "Available" tab to enroll in your courses.'
            : 'Try a different search, or check back later.',
        actionLabel: isEnrolledTab ? 'Refresh' : null,
        onAction: isEnrolledTab ? _fetchCourses : null,
        accentColor: AppColors.primary,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          final courseId = course['id'];
          final code = course['course_code'] ?? 'N/A';
          final title = course['title'] ?? 'Untitled Course';
          final dept = course['department'] ?? 'SUST';
          final teacher = course['teacher_name'] ?? 'Faculty Member';
          final teacherEmail = course['teacher_email'] ?? '';

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
                        label: code,
                        background: AppColors.primaryLight,
                        foreground: AppColors.primaryDark,
                        icon: Icons.book_rounded,
                      ),
                      BrandBadge(
                        label: dept,
                        color: AppColors.textSecondary,
                        icon: Icons.account_balance,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.person_pin_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          teacher,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (teacherEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            teacherEmail,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEnrolledTab) ...[
                        GhostButton(
                          label: 'Drop',
                          icon: Icons.delete_outline,
                          color: AppColors.danger,
                          onPressed: () => _unenrollCourse(courseId, code),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Give Attendance',
                          icon: Icons.qr_code_scanner_rounded,
                          gradient: AppGradients.success,
                          height: 40,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const StudentAttendanceScreen()),
                            );
                          },
                        ),
                      ] else
                        PrimaryButton(
                          label: 'Enroll in Course',
                          icon: Icons.add_circle_outline,
                          gradient: AppGradients.primary,
                          height: 40,
                          onPressed: () => _enrollCourse(courseId, code),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}