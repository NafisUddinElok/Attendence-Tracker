import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/app_config.dart';
import '../teacher_session_screen.dart';
import '../teacher_report_screen.dart';
import '../../theme/app_theme.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchTeacherCourses();
  }

  Future<void> _fetchTeacherCourses() async {
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
          _courses = data['courses'] ?? [];
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
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCourse(String courseId, String courseCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text('Delete $courseCode?'),
        content: const Text(
            'This will permanently remove the course and its related attendance sessions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Delete',
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
        Uri.parse('$baseUrl/api/courses/$courseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course $courseCode deleted successfully.'),
            backgroundColor: AppColors.teacherPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchTeacherCourses();
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

  void _showCreateCourseModal() {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    String selectedDept = 'IPE';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.lg,
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + AppSpacing.md,
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Create New Course',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.teacherPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Course Code',
                          hintText: 'e.g. IPE-301, CSE-231',
                          prefixIcon: const Icon(Icons.code),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Course code is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Course Title',
                          hintText: 'e.g. Supply Chain Management',
                          prefixIcon: const Icon(Icons.book_outlined),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Course title is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDept,
                        decoration: InputDecoration(
                          labelText: 'Department',
                          prefixIcon: const Icon(Icons.account_balance_outlined),
                        ),
                        items: [
                          'IPE',
                          'CSE',
                          'SWE',
                          'EEE',
                          'ME',
                          'CEE',
                          'FET',
                          'CHE',
                          'PHY',
                          'MAT'
                        ]
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedDept = val ?? 'IPE'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Add Course',
                        icon: Icons.add_circle_outline,
                        gradient: AppGradients.teacher,
                        loading: isSubmitting,
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);

                                final navigator = Navigator.of(modalCtx);
                                final messenger = ScaffoldMessenger.of(context);

                                try {
                                  final baseUrl = await AppConfig.getBaseUrl();
                                  final token =
                                      await _storage.read(key: 'jwt_token');
                                  final response = await http.post(
                                    Uri.parse('$baseUrl/api/courses'),
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Authorization': 'Bearer $token',
                                    },
                                    body: jsonEncode({
                                      'courseCode':
                                          codeCtrl.text.trim().toUpperCase(),
                                      'title': titleCtrl.text.trim(),
                                      'department': selectedDept,
                                    }),
                                  ).timeout(const Duration(seconds: 8));

                                  final resData = jsonDecode(response.body);

                                  if (response.statusCode == 201 ||
                                      response.statusCode == 200) {
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            '✅ Course created successfully!'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    if (!mounted) return;
                                    _fetchTeacherCourses();
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(resData['message'] ??
                                            'Failed to create course'),
                                        backgroundColor: AppColors.danger,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Connection failed: $e'),
                                      backgroundColor: AppColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        expand: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'My Courses · Instructor',
        gradient: AppGradients.teacherDeep,
        showBackButton: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.teacher,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.brand,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreateCourseModal,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: const Text('New Course',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTeacherCourses,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teacherPrimary))
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
                          gradient: AppGradients.teacher,
                          onPressed: _fetchTeacherCourses,
                        ),
                      ],
                    ),
                  )
                : _courses.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'No courses yet',
                        subtitle:
                            'Tap the "New Course" button below to create your first course.',
                        accentColor: AppColors.teacherPrimary,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _courses.length,
                        itemBuilder: (context, index) {
                          final course = _courses[index];
                          final courseId = course['id'];
                          final code = course['course_code'] ?? 'N/A';
                          final title = course['title'] ?? 'Untitled';
                          final dept = course['department'] ?? 'SUST';
                          final enrolledCount =
                              course['enrolled_students_count'] ?? 0;

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
                                        background: AppColors.teacherLight,
                                        foreground: AppColors.teacherPrimary,
                                        icon: Icons.menu_book_rounded,
                                      ),
                                      Row(
                                        children: [
                                          BrandBadge(
                                            label: '$enrolledCount Students',
                                            color: AppColors.info,
                                            icon: Icons.group_outlined,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline,
                                                color: AppColors.danger, size: 20),
                                            onPressed: () =>
                                                _deleteCourse(courseId, code),
                                            tooltip: 'Delete Course',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Department: $dept',
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const Divider(height: 1),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GhostButton(
                                          label: 'Reports',
                                          icon: Icons.bar_chart_rounded,
                                          color: AppColors.teacherPrimary,
                                          expand: true,
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TeacherReportScreen(
                                                  courseId: courseId,
                                                  courseCode: code,
                                                  courseTitle: title,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: PrimaryButton(
                                          label: 'Live QR',
                                          icon: Icons.qr_code_scanner_rounded,
                                          gradient: AppGradients.teacher,
                                          height: 42,
                                          expand: true,
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TeacherSessionScreen(
                                                  courseId: courseId,
                                                  courseCode: code,
                                                  courseTitle: title,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}