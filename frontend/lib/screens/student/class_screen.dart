import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';

class ClassScreen extends ConsumerStatefulWidget {
  final String classId;
  const ClassScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  Map<String, dynamic>? _sessionData;
  bool _loading = true;
  bool _claiming = false;
  bool _claimed = false;
  String? _claimError;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkSession());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      final data =
          await ref.read(apiClientProvider).getActiveSession(widget.classId);
      if (mounted) {
        setState(() {
          _sessionData = data;
          _loading = false;
        });
        if (data['active'] == true && _secondsLeft == 0) {
          _startCountdown(data);
        }
        if (data['alreadyClaimed'] == true) {
          _claimed = true;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown(Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'] as String?;
    if (expiresAt == null) return;
    final expires = DateTime.tryParse(expiresAt);
    if (expires == null) return;
    final left = expires.difference(DateTime.now().toUtc()).inSeconds;
    setState(() => _secondsLeft = left > 0 ? left : 0);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _sessionData?['active'] = false;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _claimAttendance() async {
    final session = _sessionData;
    if (session == null || session['active'] != true) return;

    setState(() {
      _claiming = true;
      _claimError = null;
    });

    try {
      bool serviceEnabled = true;
      if (!kIsWeb) {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      if (!serviceEnabled) {
        setState(() => _claimError = 'Please turn on GPS / Location services.');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _claimError =
            'Location permission is required to mark attendance.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw 'Location acquisition timed out. Please ensure GPS is enabled.',
      );

      const uuid = Uuid();
      final deviceId = uuid.v4();

      final result = await ref.read(apiClientProvider).claimAttendance(
            sessionId: session['sessionId'] as String,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            deviceInstallId: deviceId,
          );

      if (mounted) setState(() => _claimed = true);
      ref.invalidate(studentClassesProvider);
      await _checkSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Attendance marked!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _claimError = e.message);
    } catch (e) {
      if (mounted) setState(() => _claimError = e.toString());
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _sessionData?['active'] == true;
    final stats = _sessionData?['stats'] as Map<String, dynamic>?;
    final history = _sessionData?['history'] as List<dynamic>? ?? [];
    final course = _sessionData?['course'] as Map<String, dynamic>?;

    final totalSessions = stats?['totalSessions'] as int? ?? 0;
    final presentCount = stats?['presentCount'] as int? ?? 0;
    final percentage = (stats?['percentage'] as num?)?.toDouble() ?? 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(course?['subjectCode'] as String? ?? 'Class Screen'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _checkSession();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  // 1. Live Session Box (Basic raw card)
                  if (active) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              'Live Attendance Running',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.location_on,
                              size: 48,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Radius: ${_sessionData!['radiusMeters']}m'),
                            const SizedBox(height: 8),
                            if (_claimed)
                              const Text(
                                '✓ ATTENDANCE MARKED PRESENT!',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed:
                                      _claiming ? null : _claimAttendance,
                                  child: Text(_claiming
                                      ? 'Checking GPS...'
                                      : 'SUBMIT ATTENDANCE'),
                                ),
                              ),
                            if (_claimError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _claimError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 2. Course Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                course?['subjectCode'] as String? ?? 'Course',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${percentage.round()}% ATTENDANCE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: percentage >= 75
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          if (course?['subjectName'] != null)
                            Text(course!['subjectName'] as String),
                          if (course?['teacherEmail'] != null)
                            Text(
                              'Teacher: ${course!['teacherEmail']}',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                          const SizedBox(height: 8),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('Total: $totalSessions'),
                              Text('Present: $presentCount',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                              Text('Absent: ${totalSessions - presentCount}',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Attendance History Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'Attendance History ($totalSessions sessions)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (history.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('No sessions recorded yet.',
                              style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                    )
                  else
                    ...history.map((h) {
                      final isPresent = h['isPresent'] == true;
                      final startedAt = h['startedAt'] as String?;
                      final formattedDate = startedAt != null
                          ? _formatDateTime(startedAt)
                          : 'Unknown Date';
                      final dist = h['distanceMeters'] != null
                          ? '${(h['distanceMeters'] as num).round()}m away'
                          : null;

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isPresent ? Icons.check_circle : Icons.cancel,
                            color: isPresent ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          title: Text(formattedDate,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: dist != null
                              ? Text(dist, style: const TextStyle(fontSize: 11))
                              : null,
                          trailing: Text(
                            isPresent ? 'PRESENT' : 'ABSENT',
                            style: TextStyle(
                              color: isPresent ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  String _formatDateTime(String dt) {
    try {
      final d = DateTime.parse(dt).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(d);
    } catch (_) {
      return dt;
    }
  }
}
