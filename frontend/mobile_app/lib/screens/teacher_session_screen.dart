import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  bool _isInitializing = true;
  String? _errorMessage;

  String? _sessionId;
  String? _currentQrToken;
  int _secondsRemaining = 15;
  int _checkedInCount = 0;
  final List<Map<String, dynamic>> _recentAttendees = [];

  // Bluetooth proximity check — opt-in, off by default (see note in
  // _startLiveSession: not every teacher device can reliably advertise
  // BLE, so this stays a per-session choice rather than forced on).
  bool _bleEnabled = false;
  bool _bleAdvertising = false;
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // Geofence radius — remembered per-course so a teacher who always
  // teaches in the same room doesn't have to redo this every class.
  // GPS center itself is already auto-detected (no manual lat/lng entry).
  double _radiusMeters = 100;
  String get _radiusStorageKey => 'geofence_radius_${widget.courseId}';

  Timer? _totpTimer;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadSavedRadius();
    _startLiveSession();
  }

  Future<void> _loadSavedRadius() async {
    final saved = await _storage.read(key: _radiusStorageKey);
    if (saved != null && mounted) {
      final parsed = double.tryParse(saved);
      if (parsed != null) setState(() => _radiusMeters = parsed);
    }
  }

  /// 1. Initialize GPS Lock & Start Backend Session
  Future<void> _startLiveSession() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      // GPS Coordinates — must be the REAL current location, no silent fallback.
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
          timeLimit: const Duration(seconds: 15), // was 3s — too short indoors
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        // No silent fallback to a hardcoded "SUST Center" point anymore —
        // that was silently mis-setting the geofence center whenever GPS
        // lock timed out, causing every student to fail with
        // "outside classroom boundary".
        if (mounted) {
          setState(() {
            _errorMessage =
                'Could not get your current location: $e\n\nPlease make sure GPS is on '
                '(stepping near a window can help indoors), then try again.';
            _isInitializing = false;
          });
        }
        return;
      }

      // Try calling primary session endpoint
      Uri sessionUri = Uri.parse('$baseUrl/api/sessions/start');
      var response = await http.post(
        sessionUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'courseId': widget.courseId,
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': _radiusMeters.round(),
          'enableBle': _bleEnabled,
        }),
      ).timeout(const Duration(seconds: 8));

      // Fallback: If 404, try alternate route /api/sessions
      if (response.statusCode == 404) {
        sessionUri = Uri.parse('$baseUrl/api/sessions');
        response = await http.post(
          sessionUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'courseId': widget.courseId,
            'latitude': latitude,
            'longitude': longitude,
            'radiusMeters': _radiusMeters.round(),
            'enableBle': _bleEnabled,
          }),
        ).timeout(const Duration(seconds: 8));
      }

      // Check if response is valid JSON
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final session = data['session'] ?? data['data'];
        final String? bleUuid = session['ble_uuid'];

        // If BLE was requested and the backend generated a UUID for this
        // session, start advertising it now. If advertising fails (device
        // doesn't support peripheral mode, permission denied, etc.), the
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
                _isInitializing = false;
              });
            }
            return;
          }
        }

        setState(() {
          _sessionId = session['id'];
          _currentQrToken = data['qrToken'] ?? session['id'];
          _isInitializing = false;
        });

        await _storage.write(key: _radiusStorageKey, value: _radiusMeters.round().toString());

        _initSocket(baseUrl, _sessionId!);
        _startTotpCountdown();
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
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection failed: $e';
        _isInitializing = false;
      });
    }
  }

  /// 2. Real-Time Socket.IO Live Counter Feed
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

  /// 3. 15-Second Dynamic QR Token Rotation
  void _startTotpCountdown() {
    _totpTimer?.cancel();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _secondsRemaining = 15);
        await _refreshDynamicQrToken();
      }
    });
  }

  Future<void> _refreshDynamicQrToken() async {
    if (_sessionId == null) return;
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/sessions/$_sessionId/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _currentQrToken = data['qrToken'];
          });
        }
      }
    } catch (_) {}
  }

  /// 4. End Session
  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Live Attendance?'),
        content: const Text('This will close the dynamic QR session. Students will no longer be able to scan.'),
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
        Uri.parse('$baseUrl/api/sessions/$_sessionId/end'),
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
  /// advertising fails right after session creation, so we don't leave a
  /// live session behind that requires a beacon nobody is broadcasting.
  Future<void> _endSessionSilently(String sessionId, String baseUrl, String? token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/sessions/$sessionId/end'),
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
    _totpTimer?.cancel();
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
          if (!_isInitializing && _sessionId != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              tooltip: 'End Session',
              onPressed: _endSession,
            ),
        ],
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.indigo),
                  const SizedBox(height: 16),
                  const Text('Initializing Anti-Proxy Engine...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Locking GPS Geofence & Starting Session for ${widget.courseCode}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Classroom radius', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                            Text('${_radiusMeters.round()}m', style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: _radiusMeters,
                          min: 20,
                          max: 300,
                          divisions: 28,
                          activeColor: Colors.indigo,
                          onChanged: (val) => setState(() => _radiusMeters = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 54),
                        const SizedBox(height: 14),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _startLiveSession,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
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
                              'LIVE TOTP SESSION ACTIVE',
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
                      const SizedBox(height: 18),

                      // Dynamic QR Code Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_currentQrToken != null)
                              QrImageView(
                                data: _currentQrToken!,
                                version: QrVersions.auto,
                                size: 230.0,
                              )
                            else
                              const SizedBox(height: 230, child: Center(child: CircularProgressIndicator())),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    value: _secondsRemaining / 15.0,
                                    strokeWidth: 3,
                                    color: _secondsRemaining <= 4 ? Colors.redAccent : Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Rotates in $_secondsRemaining seconds',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _secondsRemaining <= 4 ? Colors.redAccent : Colors.black87,
                                  ),
                                ),
                              ],
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
                ),
    );
  }
}