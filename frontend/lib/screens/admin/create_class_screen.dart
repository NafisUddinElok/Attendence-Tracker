import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _subjectCodeCtrl = TextEditingController();
  final _subjectNameCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController(text: '2023-24');
  final _formKey = GlobalKey<FormState>();

  String? _selectedDept;
  String? _selectedSemester;
  String? _selectedTeacherId;
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = false;
  bool _loadingTeachers = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _subjectCodeCtrl.dispose();
    _subjectNameCtrl.dispose();
    _sessionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers([String? dept]) async {
    setState(() => _loadingTeachers = true);
    try {
      final api = ref.read(apiClientProvider);
      final teachers = await api.getTeachers(department: dept);
      if (mounted) {
        setState(() {
          _teachers = teachers;
          if (_selectedTeacherId != null &&
              !_teachers.any((t) => t['id'] == _selectedTeacherId)) {
            _selectedTeacherId = null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teachers = []);
    } finally {
      if (mounted) setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _success = false;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.createClass({
        'department': _selectedDept,
        'academicSession': _sessionCtrl.text.trim(),
        'semester': _selectedSemester ?? '',
        'subjectCode': _subjectCodeCtrl.text.trim(),
        'subjectName': _subjectNameCtrl.text.trim(),
        'teacherId': _selectedTeacherId,
      });

      ref.invalidate(adminClassesProvider);
      ref.invalidate(teacherClassesProvider);
      ref.invalidate(studentClassesProvider);

      setState(() {
        _success = true;
        _subjectCodeCtrl.clear();
        _subjectNameCtrl.clear();
        _selectedTeacherId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Classroom'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Classroom Information',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Department:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDept,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: kDepartments
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedDept = v);
                        _loadTeachers(v);
                      },
                      validator: (v) =>
                          v == null ? 'Select a department' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Session:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _sessionCtrl,
                                decoration: const InputDecoration(
                                  hintText: '2023-24',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Semester:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSemester,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                ),
                                items: kSemesters
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedSemester = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Subject Code:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _subjectCodeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. SWE-301',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text('Subject Name (Optional):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _subjectNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Software Architecture',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Assigned Teacher:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedTeacherId,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        suffixIcon: _loadingTeachers
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              )
                            : null,
                      ),
                      items: _teachers.map((t) {
                        final email = t['email'] as String? ?? 'Teacher';
                        final dept = t['department'] as String? ?? '';
                        return DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(
                            dept.isNotEmpty ? '$email ($dept)' : email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedTeacherId = v),
                      validator: (v) => v == null ? 'Select a teacher' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _create,
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('CREATE CLASSROOM'),
                      ),
                    ),
                    if (_success) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Classroom created & students auto-enrolled!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
