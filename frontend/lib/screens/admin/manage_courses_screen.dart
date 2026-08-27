import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({super.key});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  List<CourseModel> _courses = [];
  List<AppUser> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final coursesRes = await ApiService.get(ApiConfig.adminCourses);
      final teachersRes = await ApiService.get(ApiConfig.adminTeachers);

      final coursesData = ApiService.decodeOrThrow(coursesRes) as List;
      final teachersData = ApiService.decodeOrThrow(teachersRes) as List;

      setState(() {
        _courses = coursesData.map((e) => CourseModel.fromJson(e)).toList();
        _teachers = teachersData.map((e) => AppUser.fromJson(e)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddCourseDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    int? selectedTeacherId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Course Name')),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Course Code')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Assign Teacher'),
                  items: _teachers
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedTeacherId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final res = await ApiService.post(ApiConfig.adminCourses, {
                    'course_name': nameCtrl.text.trim(),
                    'course_code': codeCtrl.text.trim(),
                    'teacher_id': selectedTeacherId,
                  });
                  ApiService.decodeOrThrow(res);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _load();
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnrollDialog(CourseModel course) {
    final regNoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enroll student in ${course.courseName}'),
        content: TextField(
          controller: regNoCtrl,
          decoration: const InputDecoration(labelText: 'Student ID (numeric) or use Students tab'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final studentId = int.tryParse(regNoCtrl.text.trim());
                if (studentId == null) throw Exception('Enter a valid numeric student ID');
                final res = await ApiService.post(ApiConfig.adminEnroll, {
                  'course_id': course.id,
                  'student_id': studentId,
                });
                ApiService.decodeOrThrow(res);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student enrolled successfully')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCourseDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final c = _courses[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                      title: Text(c.courseName),
                      subtitle: Text('${c.courseCode}${c.teacherName != null ? ' • ${c.teacherName}' : ' • unassigned'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: 'Enroll student',
                        onPressed: () => _showEnrollDialog(c),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
