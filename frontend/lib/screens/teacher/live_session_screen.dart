import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/classes_provider.dart';

enum AttendanceMode { manual, automated }

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String classId;
  const LiveSessionScreen({super.key, required this.classId});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  AttendanceMode _mode = AttendanceMode.manual;

  // Automated mode state
  SessionModel? _session;
  bool _loading = false;
  double _radius = 30.0;
  int _duration = 60;
  List<CheckInRecord> _checkIns = [];
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  final List<Map<String, dynamic>> _radiusPresets = [
    {'label': '30m (Classroom)', 'value': 30.0},
    {'label': '50m (Hall)', 'value': 50.0},
    {'label': '100m (Building)', 'value': 100.0},
    {'label': '500m (Campus)', 'value': 500.0},
    {'label': 'Unlimited (Test)', 'value': 99999.0},
  ];

  // Manual roll-call state
  List<EnrolledStudent> _students = [];
  bool _loadingStudents = false;
  final Map<String, String> _attendanceMap = {}; // regNo -> 'P' or 'A'
  bool _savingManual = false;
  String? _manualSuccessMsg;

  @override
  void initState() {
    super.initState();
    _loadEnrolledStudents();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEnrolledStudents() async {
    setState(() => _loadingStudents = true);
    try {
      final students =
          await ref.read(apiClientProvider).getClassStudents(widget.classId);
      setState(() {
        _students = students;
        for (final s in students) {
          _attendanceMap.putIfAbsent(s.registrationNo, () => 'P');
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _startAutomatedSession() async {
    setState(() => _loading = true);
    try {
      double lat = 24.9008;
      double lon = 91.9224;

      try {
        bool serviceEnabled = true;
        if (!kIsWeb) {
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }

        if (serviceEnabled) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }

          if (perm == LocationPermission.whileInUse ||
              perm == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 4),
              ),
            ).timeout(const Duration(seconds: 4));
            lat = pos.latitude;
            lon = pos.longitude;
          }
        }
      } catch (e) {
        debugPrint('[LiveSession] Location acquisition fallback: $e');
      }

      final session = await ref.read(apiClientProvider).startSession(
            classId: widget.classId,
            latitude: lat,
            longitude: lon,
            radiusMeters: _radius,
            durationSeconds: _duration,
          );
      setState(() {
        _session = session;
        _secondsLeft = _duration;
      });
      ref.invalidate(teacherClassesProvider);
      ref.invalidate(studentClassesProvider);
      _startPolling();
      _startCountdown();
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_session == null) return;
      try {
        final data =
            await ref.read(apiClientProvider).getSessionRecords(_session!.id);
        if (mounted) {
          setState(() {
            _checkIns = (data['checkIns'] as List<dynamic>)
                .map((r) => CheckInRecord.fromJson(r as Map<String, dynamic>))
                .toList();
          });
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _endAutomatedSession();
        }
      });
    });
  }

  Future<void> _endAutomatedSession() async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (_session != null) {
      try {
        await ref.read(apiClientProvider).endSession(_session!.id);
      } catch (_) {}
    }
    ref.invalidate(teacherClassesProvider);
    ref.invalidate(studentClassesProvider);
    if (mounted) {
      setState(() {
        _session = null;
        _checkIns = [];
        _secondsLeft = 0;
      });
    }
  }

  Future<void> _saveManualAttendance() async {
    if (_students.isEmpty) return;

    setState(() {
      _savingManual = true;
      _manualSuccessMsg = null;
    });

    try {
      final records = _students.map((s) {
        return {
          'registrationNo': s.registrationNo,
          'status': _attendanceMap[s.registrationNo] ?? 'P',
        };
      }).toList();

      final result = await ref.read(apiClientProvider).saveManualAttendance(
            classId: widget.classId,
            records: records,
          );

      ref.invalidate(teacherClassesProvider);
      ref.invalidate(studentClassesProvider);

      setState(() {
        _manualSuccessMsg = result['message'] as String? ??
            'Manual attendance recorded successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_manualSuccessMsg!),
            backgroundColor: Colors.green,
          ),
        );
      }
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
      setState(() => _savingManual = false);
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final s in _students) {
        _attendanceMap[s.registrationNo] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _session != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Session'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            // Mode Selector: Manual on LEFT, Automated (GPS) on RIGHT
            if (!active) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == AttendanceMode.manual
                            ? Colors.blue
                            : Colors.grey.shade200,
                        foregroundColor: _mode == AttendanceMode.manual
                            ? Colors.white
                            : Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: _mode == AttendanceMode.manual
                                ? Colors.blue
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _mode = AttendanceMode.manual),
                      child: const Text('Manual (Roll Call)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == AttendanceMode.automated
                            ? Colors.blue
                            : Colors.grey.shade200,
                        foregroundColor: _mode == AttendanceMode.automated
                            ? Colors.white
                            : Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: _mode == AttendanceMode.automated
                                ? Colors.blue
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _mode = AttendanceMode.automated),
                      child: const Text('Automated (GPS)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ── Mode 1: Manual (Roll Call) — DEFAULT ────────────────────────
            if (_mode == AttendanceMode.manual && !active) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: ${_students.length}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Present: ${_countStatus('P')}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text('Absent: ${_countStatus('A')}',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _markAll('P'),
                            child: const Text('ALL PRESENT'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _markAll('A'),
                            child: const Text('ALL ABSENT'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (_loadingStudents)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
              else if (_students.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No students in class.')))
              else ...[
                // Student list with 46x44px touch targets
                ..._students.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final isPresent =
                      (_attendanceMap[s.registrationNo] ?? 'P') == 'P';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isPresent
                            ? const Color(0xFFB7E4C7)
                            : const Color(0xFFFFCCD5),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey.shade200,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black87)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.registrationNo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (s.department != null)
                                Text(s.department!,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Large P Button (min 44x44 tap target)
                        InkWell(
                          onTap: () => setState(
                              () => _attendanceMap[s.registrationNo] = 'P'),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 46,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPresent
                                  ? Colors.green
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: isPresent
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                width: isPresent ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    isPresent ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Large A Button (min 44x44 tap target)
                        InkWell(
                          onTap: () => setState(
                              () => _attendanceMap[s.registrationNo] = 'A'),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 46,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !isPresent
                                  ? Colors.red
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: !isPresent
                                    ? Colors.red
                                    : Colors.grey.shade400,
                                width: !isPresent ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'A',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    !isPresent ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _savingManual ? null : _saveManualAttendance,
                    child: Text(_savingManual
                        ? 'SAVING...'
                        : 'SAVE ATTENDANCE (${_countStatus('P')}/${_students.length} P)'),
                  ),
                ),
              ],
            ],

            // ── Mode 2: Automated (GPS) ─────────────────────────────────────
            if (_mode == AttendanceMode.automated || active) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 50,
                      color: active ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    if (active) ...[
                      Text(
                        '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_checkIns.length} student(s) checked in',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: _endAutomatedSession,
                          child: const Text('STOP SESSION'),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Set radius and duration below to start.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              if (!active) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Radius:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: _radiusPresets.map((p) {
                          final val = p['value'] as double;
                          final selected = _radius == val;
                          return ChoiceChip(
                            label: Text(p['label'] as String,
                                style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) => setState(() => _radius = val),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      const Text('Duration:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: kSessionDurations.map((d) {
                          final selected = _duration == d;
                          return ChoiceChip(
                            label: Text(d >= 60 ? '${d ~/ 60}m' : '${d}s',
                                style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) => setState(() => _duration = d),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _startAutomatedSession,
                          child: Text(_loading
                              ? 'STARTING...'
                              : 'START GPS ATTENDANCE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_checkIns.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Check-ins (${_checkIns.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._checkIns.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(r.registrationNo,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${r.distanceMeters?.round() ?? 0}m away',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  int _countStatus(String status) {
    return _students
        .where((s) => (_attendanceMap[s.registrationNo] ?? 'P') == status)
        .length;
  }
}
