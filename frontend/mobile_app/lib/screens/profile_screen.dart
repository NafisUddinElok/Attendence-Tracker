import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/app_config.dart';
import '../services/device_service.dart';
import 'auth/login_screen.dart';
import 'face_register_screen.dart';

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
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of SUST Attendance Hub?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Log Out'),
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Account & Security'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Profile Header Card
            _buildProfileHeader(),

            const SizedBox(height: 20),

            // 2. Hardware Device Binding & Anti-Proxy Security Section
            const Text(
              'ANTI-PROXY HARDWARE BINDING',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            _buildDeviceBindingCard(),

            const SizedBox(height: 20),

            // 3. Network & System Configuration
            const Text(
              'SYSTEM CONFIGURATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(),

            const SizedBox(height: 28),

            // 4. Log Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Sign Out from this Device',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.indigo.shade50,
            child: Text(
              _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _role == 'STUDENT'
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.deepPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _role == 'STUDENT' ? '🎓 SUST Student' : '👨‍🏫 Faculty Member',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _role == 'STUDENT' ? Colors.green.shade800 : Colors.deepPurple,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phonelink_lock, color: Colors.indigo, size: 20),
                    SizedBox(width: 8),
                    Text('Hardware Device Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVE 🔒',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your attendance submissions are cryptographically bound to this physical hardware UUID:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentDeviceId,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.indigo),
                    tooltip: 'Copy UUID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _currentDeviceId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device UUID copied to clipboard!'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.face_retouching_natural, color: Colors.teal, size: 20),
                    SizedBox(width: 8),
                    Text('Biometric Vector (192-D)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FaceRegisterScreen()),
                    ).then((_) => _loadProfileData());
                  },
                  child: const Text('Re-Enroll Face', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: Colors.indigo),
            title: const Text('Backend Server URL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_serverUrl, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () {
              AppConfig.showServerConfigDialog(
                context,
                onSaved: () => _loadProfileData(),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined, color: Colors.indigo),
            title: Text('SUST Attendance Protocol', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('v2.4.0 • Anti-Proxy Secured', style: TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: Icon(Icons.check_circle, color: Colors.green, size: 18),
          ),
        ],
      ),
    );
  }
}