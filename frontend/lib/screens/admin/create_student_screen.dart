import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';

class CreateStudentScreen extends ConsumerStatefulWidget {
  const CreateStudentScreen({super.key});

  @override
  ConsumerState<CreateStudentScreen> createState() =>
      _CreateStudentScreenState();
}

class _CreateStudentScreenState extends ConsumerState<CreateStudentScreen> {
  final _regCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _parsedDept;
  String? _parsedSession;
  String? _successMsg;

  @override
  void dispose() {
    _regCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onRegChanged(String val) {
    if (val.length >= 7) {
      final year = int.tryParse(val.substring(0, 4));
      final deptCode = val.substring(4, 7);
      final deptMap = {
        '831': 'Software Engineering',
        '331': 'Computer Science & Engineering',
        '131': 'EEE',
        '231': 'Civil Engineering',
        '431': 'Mechanical Engineering',
      };
      setState(() {
        _parsedDept = deptMap[deptCode] ?? 'Unknown ($deptCode)';
        if (year != null) {
          final next = (year + 1) % 100;
          _parsedSession = '$year-${next.toString().padLeft(2, '0')}';
        }
      });
    } else {
      setState(() {
        _parsedDept = null;
        _parsedSession = null;
      });
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _successMsg = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.createStudent(
        _regCtrl.text.trim(),
        _passCtrl.text,
      );
      ref.invalidate(adminClassesProvider);
      setState(() {
        _successMsg = result['message'] as String? ??
            'Student saved! Dept: ${result['department']}, Session: ${result['academicSession']}';
        _regCtrl.clear();
        _passCtrl.clear();
        _parsedDept = null;
        _parsedSession = null;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
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
                      'Student Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Registration Number:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _regCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 2023831018',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: _onRegChanged,
                      validator: (v) {
                        if (v == null || v.trim().length < 10) {
                          return 'Enter a valid 10-digit registration number';
                        }
                        return null;
                      },
                    ),
                    if (_parsedDept != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dept: $_parsedDept • Session: $_parsedSession',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Password:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Default: same as reg number',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
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
                            : const Text('ADD STUDENT'),
                      ),
                    ),
                    if (_successMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _successMsg!,
                        style: const TextStyle(
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
