import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConfig.adminNotifications);
      final data = ApiService.decodeOrThrow(res) as List;
      setState(() => _notifications = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resolve(int notificationId) async {
    try {
      final res = await ApiService.post(ApiConfig.adminResolveNotification(notificationId), {});
      ApiService.decodeOrThrow(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student enrolled and notification resolved')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No pending notifications')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final course = n['Course'];
                        final sender = n['sender'];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_add_alt_1, color: Colors.orange),
                            title: Text(
                              'Reg No: ${n['student_registration_number']} → ${course?['course_name'] ?? ''}',
                            ),
                            subtitle: Text(
                              '${n['message'] ?? ''}\nRequested by: ${sender?['name'] ?? 'teacher'}',
                            ),
                            isThreeLine: true,
                            trailing: ElevatedButton(
                              onPressed: () => _resolve(n['id']),
                              child: const Text('Approve'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
