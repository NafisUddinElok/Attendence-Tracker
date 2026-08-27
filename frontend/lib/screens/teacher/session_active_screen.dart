import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/course_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';

class SessionActiveScreen extends StatefulWidget {
  final CourseModel course;
  const SessionActiveScreen({super.key, required this.course});

  @override
  State<SessionActiveScreen> createState() => _SessionActiveScreenState();
}

class _SessionActiveScreenState extends State<SessionActiveScreen> {
  bool _starting = false;
  bool _ending = false;
  int? _sessionId;
  double _radius = 100;
  String? _statusMessage;
  bool _isError = false;

  Future<void> _startSession() async {
    setState(() {
      _starting = true;
      _statusMessage = null;
    });
    try {
      final position = await LocationService.getCurrentLocation();

      final res = await ApiService.post(ApiConfig.teacherSessionStart, {
        'course_id': widget.course.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'radius_meters': _radius.toInt(),
      });

      final data = ApiService.decodeOrThrow(res);
      setState(() {
        _sessionId = data['session']['id'];
        _statusMessage = 'Session started. Students within ${_radius.toInt()}m can now mark attendance.';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    } finally {
      setState(() => _starting = false);
    }
  }

  Future<void> _endSession() async {
    if (_sessionId == null) return;
    setState(() {
      _ending = true;
      _statusMessage = null;
    });
    try {
      final res = await ApiService.post(ApiConfig.teacherSessionEnd(_sessionId!), {});
      ApiService.decodeOrThrow(res);
      setState(() {
        _statusMessage = 'Session ended. Attendance CSV generated.';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    } finally {
      setState(() => _ending = false);
    }
  }

  Future<void> _downloadSessionCsv() async {
    if (_sessionId == null) return;
    final token = await AuthService.getToken();
    final url = '${ApiConfig.teacherSessionCsv(_sessionId!)}?token=$token';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.course.courseName} — Session')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sessionId == null) ...[
              const Text('Allowed check-in radius', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _radius,
                min: 20,
                max: 300,
                divisions: 28,
                label: '${_radius.toInt()}m',
                onChanged: (v) => setState(() => _radius = v),
              ),
              Text('${_radius.toInt()} meters', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _starting ? null : _startSession,
                icon: _starting
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: Text(_starting ? 'Getting location...' : 'Start Session Here'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                ),
              ),
            ] else ...[
              Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 12),
                      SizedBox(width: 8),
                      Text('Session is LIVE — students can check in now.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _ending ? null : _endSession,
                icon: _ending
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.stop),
                label: Text(_ending ? 'Ending...' : 'End Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _downloadSessionCsv,
                icon: const Icon(Icons.download),
                label: const Text('Download This Session\'s CSV'),
              ),
            ],
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
