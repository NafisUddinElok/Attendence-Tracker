import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../auth_controller.dart';
import '../../domain/role.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  AppRole _role = AppRole.student;

  // Shared
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _department = TextEditingController();

  // Student
  final _regNo = TextEditingController();
  final _session = TextEditingController();

  // Teacher
  final _teacherId = TextEditingController();
  final _designation = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _tabs.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _department.dispose();
    _regNo.dispose();
    _session.dispose();
    _teacherId.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final notifier = ref.read(authControllerProvider.notifier);
    if (_role == AppRole.student) {
      await notifier.registerStudent(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        registrationNo: _regNo.text.trim(),
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
        session: _session.text.trim().isEmpty ? null : _session.text.trim(),
      );
    } else {
      await notifier.registerTeacher(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        teacherId: _teacherId.text.trim(),
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
        designation: _designation.text.trim().isEmpty
            ? null
            : _designation.text.trim(),
      );
    }
  }

  String? _friendlyError(Object? err) {
    if (err is ApiException) {
      switch (err.code) {
        case 'EMAIL_TAKEN':
          return 'That email is already registered.';
        case 'REG_NO_TAKEN':
          return 'That registration number is already registered.';
        case 'TEACHER_ID_TAKEN':
          return 'That teacher ID is already registered.';
        case 'VALIDATION_FAILED':
          return err.details?['issues']?.toString() ??
              'Please check your input and try again.';
        case 'NETWORK_ERROR':
        case 'TIMEOUT':
          return 'Cannot reach the server. Check your connection.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;
    final errorMsg = state.hasError ? _friendlyError(state.error) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined), text: 'Student'),
            Tab(icon: Icon(Icons.cast_for_education_outlined), text: 'Teacher'),
          ],
          onTap: (i) => setState(() {
            _role = i == 0 ? AppRole.student : AppRole.teacher;
          }),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 2) return 'Enter your full name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(s)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if ((v ?? '').length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _department,
                      decoration: const InputDecoration(
                        labelText: 'Department (optional)',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _tabs,
                      builder: (_, __) {
                        if (_tabs.index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _regNo,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Registration No (10 digits)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (!RegExp(r'^\d{10}$').hasMatch(s)) {
                                    return 'Enter a 10-digit registration number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _session,
                                decoration: const InputDecoration(
                                  labelText: 'Session (e.g. 2023-24)',
                                  prefixIcon: Icon(Icons.event_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _teacherId,
                              decoration: const InputDecoration(
                                labelText: 'Teacher ID',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Teacher ID is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _designation,
                              decoration: const InputDecoration(
                                labelText: 'Designation (optional)',
                                prefixIcon: Icon(Icons.workspace_premium_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorMsg,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: Text(
                        isLoading ? 'Creating…' : 'Create Account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}