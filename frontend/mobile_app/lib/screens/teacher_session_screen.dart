import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../services/app_config.dart';

class TeacherSessionScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;

  const TeacherSessionScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
  });

  @override
  State<TeacherSessionScreen> createState() => _TeacherSessionScreenState();
}

class _TeacherSessionScreenState extends State<TeacherSessionScreen> {
  final _storage = const FlutterSecureStorage();

  // Two phases: a "setup" screen where the teacher configures the
  // geofence + timing before going live, and the "live" screen once the
  // session has actually started on the backend.
  bool _isConfiguring = true;
  bool _isStarting = false;
  String? _errorMessage;

  String? _sessionId;
  DateTime? _expiresAt;
  int _checkedInCount = 0;
  final List<Map<String, dynamic>> _recentAttendees = [];

  Timer? _remainingTimer;
  Duration _remaining = Duration.zero;

  // Bluetooth proximity check — opt-in, off by default (not every teacher
  // device can reliably advertise BLE, so this stays a per-session choice
  // rather than forced on).
  bool _bleEnabled = false;
  bool _bleAdvertising = false;
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // ---- Teacher-configurable session settings ----
  // Geofence radius — remembered per-course so a teacher who always
  // teaches in the same room doesn't have to redo this every class.
  double _radiusMeters = 100;
  String get _radiusStorageKey => 'geofence_radius_${widget.courseId}';

  // Session length ("how long the geofence stays open"), in minutes.
  double _durationMinutes = 15;
  String get _durationStorageKey => 'session_duration_${widget.courseId}';

  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final savedRadius = await _storage.read(key: _radiusStorageKey);
    final savedDuration = await _storage.read(key: _durationStorageKey);
    if (!mounted) return;
    setState(() {
      if (savedRadius != null) {
        final parsed = double.tryParse(savedRadius);
        if (parsed != null) _radiusMeters = parsed;
      }
      if (savedDuration != null) {
        final parsed = double.tryParse(savedDuration);
        if (parsed != null) _durationMinutes = parsed;
      }
    });
  }

  /// Starts the live geofenced session on the backend using whatever
  /// radius / duration / BLE settings the teacher configured above.
  Future<void> _startLiveSession() async {
    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      // GPS Coordinates — must be the REAL current location, no silent
      // fallback (a silently mis-set geofence center fails every student
      // with "outside classroom boundary").
      double latitude;
      double longitude;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception(
              'Location permission denied. Please enable it from app settings.');
        }

        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception(
              'Location services are turned off. Please enable GPS and try again.');
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Could not get your current location: $e\n\nPlease make sure GPS is on '
                '(stepping near a window can help indoors), then try again.';
            _isStarting = false;
          });
        }
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/attendance/session/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courseId': widget.courseId,
          'title': widget.courseCode,
          'centerLat': latitude,
          'centerLng': longitude,
          'radiusMeters': _radiusMeters.round(),
          'durationMinutes': _durationMinutes.round(),
          'enableBle': _bleEnabled,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final session = data['session'] ?? data['data'];
        final String? bleUuid = session['bleUuid'];

        // If BLE was requested and the backend generated a UUID for this
        // session, start advertising it now. If advertising fails, the
        // session already requires BLE server-side — rather than leave a
        // session no student can ever pass, end it and ask the teacher to
        // retry with the toggle off.
        if (_bleEnabled && bleUuid != null && bleUuid.isNotEmpty) {
          try {
            await _blePeripheral.start(
              advertiseData: AdvertiseData(
                serviceUuid: bleUuid,
                includeDeviceName: false,
              ),
            );
            _bleAdvertising = true;
          } catch (e) {
            await _endSessionSilently(session['id'], baseUrl, token);
            if (mounted) {
              setState(() {
                _errorMessage =
                    "Bluetooth advertising couldn't start on this device ($e).\n\n"
                    'The session was cancelled automatically. Please retry with '
                    'Bluetooth proximity check turned off.';
                _isStarting = false;
              });
            }
            return;
          }
        }

        await _storage.write(key: _radiusStorageKey, value: _radiusMeters.round().toString());
        await _storage.write(key: _durationStorageKey, value: _durationMinutes.round().toString());

        setState(() {
          _sessionId = session['id'];
          _expiresAt = DateTime.tryParse(session['expiresAt'] ?? '')?.toLocal();
          _isConfiguring = false;
          _isStarting = false;
        });

        _initSocket(baseUrl, _sessionId!);
        _startRemainingTimeTicker();
      } else {
        String msg = 'Server returned Status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          msg = errorData['message'] ?? msg;
        } catch (_) {
          msg = '$msg\nResponse: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
        }
        setState(() {
          _errorMessage = msg;
          _isStarting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection failed: $e';
        _isStarting = false;
      });
    }
  }

  /// Real-Time Socket.IO Live Counter Feed
  void _initSocket(String baseUrl, String sessionId) {
    try {
      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        _socket?.emit('join_session', sessionId);
      });

      _socket?.on('student_marked', (data) {
        if (mounted) {
          setState(() {
            _checkedInCount++;
            _recentAttendees.insert(0, {
              'name': data['studentName'] ?? 'Student',
              'regNo': data['regNo'] ?? 'SUST',
              'time': DateTime.now(),
            });
          });
        }
      });
    } catch (_) {}
  }

  /// Ticks down the remaining session time shown to the teacher. Purely
  /// cosmetic — the backend independently enforces `expires_at`.
  void _startRemainingTimeTicker() {
    _remainingTimer?.cancel();
    _updateRemaining();
    _remainingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (_expiresAt == null) return;
    final diff = _expiresAt!.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    if (diff.isNegative) {
      _remainingTimer?.cancel();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// End Session
  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Live Attendance?'),
        content: const Text('This will close the geofenced session. Students will no longer be able to check in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      await http.post(
        Uri.parse('$baseUrl/api/attendance/session/$_sessionId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}

    await _stopBleAdvertising();

    if (mounted) Navigator.pop(context);
  }

  /// Ends a session without a confirmation dialog — used when BLE
  /// advertising fails right after session creation.
  Future<void> _endSessionSilently(String sessionId, String baseUrl, String? token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/attendance/session/$sessionId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> _stopBleAdvertising() async {
    if (!_bleAdvertising) return;
    try {
      await _blePeripheral.stop();
    } catch (_) {}
    _bleAdvertising = false;
  }

  @override
  void dispose() {
    _remainingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _stopBleAdvertising();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('${widget.courseCode} Live Session'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!_isConfiguring && _sessionId != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              tooltip: 'End Session',
              onPressed: _endSession,
            ),
        ],
      ),
      body: _isConfiguring ? _buildConfigView() : _buildLiveView(),
    );
  }

  // -------------------------------------------------------------
  // SETUP VIEW: teacher picks radius / duration / BLE, then starts
  // -------------------------------------------------------------
  Widget _buildConfigView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            widget.courseTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure the classroom geofence before going live',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          _buildSettingCard(
            label: 'Classroom radius',
            valueLabel: '${_radiusMeters.round()} m',
            child: Slider(
              value: _radiusMeters,
              min: 20,
              max: 300,
              divisions: 28,
              activeColor: Colors.indigo,
              onChanged: (val) => setState(() => _radiusMeters = val),
            ),
          ),
          const SizedBox(height: 14),

          _buildSettingCard(
            label: 'Session length',
            valueLabel: '${_durationMinutes.round()} min',
            child: Slider(
              value: _durationMinutes,
              min: 1,
              max: 120,
              divisions: 119,
              activeColor: Colors.indigo,
              onChanged: (val) => setState(() => _durationMinutes = val),
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bluetooth proximity check (experimental — only enable if you\'ve tested BLE works on this device)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
                Switch(
                  value: _bleEnabled,
                  onChanged: (val) => setState(() => _bleEnabled = val),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isStarting ? null : _startLiveSession,
              icon: _isStarting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sensors),
              label: Text(_isStarting ? 'Starting session...' : 'Go Live'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required String label, required String valueLabel, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              Text(valueLabel, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
            ],
          ),
          child,
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // LIVE VIEW: geofence is active, showing live check-in counter
  // -------------------------------------------------------------
  Widget _buildLiveView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  'LIVE GEOFENCE SESSION ACTIVE',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_bleAdvertising) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth, color: Colors.indigo, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'BLUETOOTH BEACON BROADCASTING',
                    style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            widget.courseTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Time-remaining + geofence summary card (replaces the old QR box)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.location_on, color: Colors.indigo, size: 46),
                const SizedBox(height: 10),
                Text(
                  '${_radiusMeters.round()} m radius',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                Text(
                  _formatDuration(_remaining),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _remaining.inMinutes < 2 ? Colors.redAccent : Colors.indigo,
                  ),
                ),
                Text(
                  'time remaining',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Checked In', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('Live Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text(
                  '$_checkedInCount',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_recentAttendees.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Submissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            ..._recentAttendees.map((attendee) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                  title: Text(attendee['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Reg: ${attendee['regNo']}'),
                  trailing: const Text('PRESENT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}