import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';
import '../services/device_service.dart';
import 'auth/login_screen.dart';
import 'face_register_screen.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();

  String _fullName = 'Loading...';
  String _email = 'Loading...';
  String _role = 'STUDENT';
  String _currentDeviceId = 'Fetching Hardware UUID...';
  String _serverUrl = '';

  bool get _isStudent => _role == 'STUDENT';
  LinearGradient get _roleGradient =>
      _isStudent ? AppGradients.primary : AppGradients.teacher;
  Color get _roleColor =>
      _isStudent ? AppColors.primary : AppColors.teacherPrimary;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final name = await _storage.read(key: 'user_name') ?? 'Muhammad Nafis';
    final email = await _storage.read(key: 'user_email') ?? 'student@student.sust.edu';
    final role = await _storage.read(key: 'user_role') ?? 'STUDENT';
    final deviceId = await DeviceService.getDeviceId();
    final url = await AppConfig.getBaseUrl();

    if (mounted) {
      setState(() {
        _fullName = name;
        _email = email;
        _role = role;
        _currentDeviceId = deviceId;
        _serverUrl = url;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of SUST Attendance Hub?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          PrimaryButton(
            label: 'Log Out',
            icon: Icons.logout,
            color: AppColors.danger,
            height: 42,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storage.deleteAll();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'Account & Security',
        gradient: _roleGradient,
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Anti-Proxy Hardware Binding'),
            _buildDeviceBindingCard(),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('System Configuration'),
            _buildSettingsCard(),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Sign Out from this Device',
              icon: Icons.logout_rounded,
              gradient: AppGradients.danger,
              onPressed: _handleLogout,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return GradientHeroCard(
      gradient: _roleGradient,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _email,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    _isStudent ? '🎓 SUST Student' : '👨‍🏫 Faculty Member',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceBindingCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.phonelink_lock, color: _roleColor, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Hardware Device Lock',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const StatusChip(
                label: 'ACTIVE',
                background: AppColors.successLight,
                foreground: AppColors.success,
                icon: Icons.lock_outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Your attendance submissions are cryptographically bound to this physical hardware UUID:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentDeviceId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: _roleColor),
                  tooltip: 'Copy UUID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentDeviceId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Device UUID copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.face_retouching_natural, color: AppColors.info, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Biometric Vector (192-D)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FaceRegisterScreen()),
                  ).then((_) => _loadProfileData());
                },
                child: Text('Re-Enroll Face',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _roleColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.dns_outlined, color: _roleColor),
            title: const Text('Backend Server URL',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_serverUrl,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
            onTap: () {
              AppConfig.showServerConfigDialog(
                context,
                onSaved: () => _loadProfileData(),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined, color: AppColors.primary),
            title: Text('SUST Attendance Protocol',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('v2.4.0 • Anti-Proxy Secured',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: Icon(Icons.check_circle, color: AppColors.success, size: 18),
          ),
        ],
      ),
    );
  }
}