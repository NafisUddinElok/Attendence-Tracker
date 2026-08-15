import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/app_config.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = 'STUDENT';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptController = TextEditingController();

  final _regNoController = TextEditingController();
  final _sessionController = TextEditingController();
  final _designationController = TextEditingController();
  final _teacherIdController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isStudent => _selectedRole == 'STUDENT';
  LinearGradient get _roleGradient =>
      _isStudent ? AppGradients.primary : AppGradients.teacher;
  Color get _roleColor =>
      _isStudent ? AppColors.primary : AppColors.teacherPrimary;

  final List<String> _sustDepartments = [
    'IPE', 'CSE', 'SWE', 'EEE', 'ME', 'CEE', 'PME', 'FET', 'CHE', 'PHY', 'MAT',
    'STA'
  ];

  @override
  void initState() {
    super.initState();
    _deptController.text = 'IPE';
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();

      final Map<String, dynamic> payload = {
        'role': _selectedRole,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'department': _deptController.text.trim(),
      };

      if (_selectedRole == 'STUDENT') {
        payload['code'] = _regNoController.text.trim();
        payload['session'] = _sessionController.text.trim();
      } else {
        payload['code'] = _teacherIdController.text.trim();
        payload['designation'] = _designationController.text.trim();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful! Please login.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Registration failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Check server connection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deptController.dispose();
    _regNoController.dispose();
    _sessionController.dispose();
    _designationController.dispose();
    _teacherIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.primaryDeep),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.dns_rounded, color: Colors.white),
                  tooltip: 'Configure Server IP',
                  onPressed: () => AppConfig.showServerConfigDialog(context),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: _roleGradient,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.brand,
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Join the SUST Attendance Hub',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Role segmented switcher (icon + label)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildRoleSelector(
                                    title: 'Student',
                                    icon: Icons.person_outline,
                                    role: 'STUDENT',
                                    gradient: AppGradients.primary,
                                  ),
                                ),
                                Expanded(
                                  child: _buildRoleSelector(
                                    title: 'Teacher',
                                    icon: Icons.psychology_outlined,
                                    role: 'TEACHER',
                                    gradient: AppGradients.teacher,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              margin: const EdgeInsets.only(bottom: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 13)),
                            ),

                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.badge_outlined,
                                  color: _roleColor),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'Enter your full name'
                                : null,
                          },
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: _roleColor),
                            ),
                            validator: (val) => val == null || !val.contains('@')
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  Icon(Icons.lock_outline, color: _roleColor),
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                    _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          DropdownButtonFormField<String>(
                            initialValue: _deptController.text,
                            decoration: InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.account_balance_outlined,
                                  color: _roleColor),
                            ),
                            items: _sustDepartments
                                .map((dept) => DropdownMenuItem(
                                      value: dept,
                                      child: Text(dept),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _deptController.text = val ?? 'IPE'),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          if (_isStudent) ...[
                            TextFormField(
                              controller: _regNoController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Registration Number',
                                hintText: 'e.g. 2023831005',
                                prefixIcon: Icon(Icons.numbers_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Registration number is required'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _sessionController,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Academic Session',
                                hintText: 'e.g. 2022-23',
                                prefixIcon: Icon(Icons.calendar_month_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Session is required'
                                  : null,
                            ),
                          ],

                          if (!_isStudent) ...[
                            TextFormField(
                              controller: _teacherIdController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Teacher / Employee ID',
                                hintText: 'e.g. EMP-101',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Teacher ID is required'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _designationController,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Designation',
                                hintText: 'e.g. Assistant Professor',
                                prefixIcon: Icon(Icons.work_outline),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Designation is required'
                                  : null,
                            ),
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          PrimaryButton(
                            label: 'Complete Registration',
                            icon: Icons.check_circle_outline,
                            gradient: _roleGradient,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _handleRegister,
                            expand: true,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector({
    required String title,
    required IconData icon,
    required String role,
    required LinearGradient gradient,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          boxShadow: isSelected ? AppShadows.soft : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}