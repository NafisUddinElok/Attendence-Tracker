import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../models/session_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../config/api_config.dart';

class ActiveSessionScreen extends StatefulWidget {
  final CourseModel course;
  const ActiveSessionScreen({super.key, required this.course});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _checking = true;
  bool _marking = false;
  SessionModel? _session;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });
    try {
      final res = await ApiService.get(
        ApiConfig.studentActiveSession(widget.course.id),
      );
      if (res.statusCode == 404) {
        setState(() {
          _session = null;
          _statusMessage = 'No active class session right now.';
          _isError = false;
        });
      } else {
        final data = ApiService.decodeOrThrow(res);
        setState(() => _session = SessionModel.fromJson(data));
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString();
        _isError = true;
      });
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _markAttendance() async {
    if (_session == null) return;
    setState(() {
      _marking = true;
      _statusMessage = null;
    });

    try {
      final position = await LocationService.getCurrentLocation();

      final res = await ApiService.post(ApiConfig.studentMarkAttendance, {
        'session_id': _session!.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      ApiService.decodeOrThrow(res); // throws if failed

      setState(() {
        _statusMessage = 'Attendance marked successfully!';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    } finally {
      setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.courseName)),
      body: RefreshIndicator(
        onRefresh: _checkActiveSession,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_checking)
              const Center(child: CircularProgressIndicator())
            else if (_session != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 12),
                          SizedBox(width: 8),
                          Text('Class session is LIVE',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${_session!.sessionDate}'),
                      Text('Allowed range: ${_session!.radiusMeters}m'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _marking ? null : _markAttendance,
                icon: _marking
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.location_on),
                label: Text(_marking ? 'Checking location...' : 'Mark My Attendance'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(child: Text('No active class session right now. Pull down to refresh.')),
                    ],
                  ),
                ),
              ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _isError ? Colors.red : Colors.green.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
