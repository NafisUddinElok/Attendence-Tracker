import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/app_config.dart';
import '../theme/app_theme.dart';

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

  Timer? _totpTimer;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _startLiveSession();
  }

  Future<void> _startLiveSession() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

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
                'Could not get your current location: $e\n\nPlease make sure GPS is on (stepping near a window can help indoors), then try again.';
            _isInitializing = false;
          });
        }
        return;
      }

      Uri sessionUri = Uri.parse('$baseUrl/api/sessions/start');
      var response = await http
          .post(
            sessionUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'courseId': widget.courseId,
              'latitude': latitude,
              'longitude': longitude,
              'radiusMeters': 100,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        sessionUri = Uri.parse('$baseUrl/api/sessions');
        response = await http
            .post(
              sessionUri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'courseId': widget.courseId,
                'latitude': latitude,
                'longitude': longitude,
                'radiusMeters': 100,
              }),
            )
            .timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final session = data['session'] ?? data['data'];
        setState(() {
          _sessionId = session['id'];
          _currentQrToken = data['qrToken'] ?? session['id'];
          _isInitializing = false;
        });

        _initSocket(baseUrl, _sessionId!);
        _startTotpCountdown();
      } else {
        String msg = 'Server returned Status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          msg = errorData['message'] ?? msg;
        } catch (_) {
          msg =
              '$msg\nResponse: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
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

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: const Text('End Live Attendance?'),
        content: const Text(
            'This will close the dynamic QR session. Students will no longer be able to scan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          PrimaryButton(
            label: 'End Session',
            icon: Icons.stop_circle_outlined,
            color: AppColors.danger,
            height: 42,
            onPressed: () => Navigator.pop(ctx, true),
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

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _secondsRemaining <= 4;
    final timerColor = isUrgent ? AppColors.danger : AppColors.teacherPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: '${widget.courseCode} · Live Session',
        gradient: AppGradients.teacherDeep,
        showBackButton: true,
        actions: [
          if (!_isInitializing && _sessionId != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.white, size: 26),
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
                  const CircularProgressIndicator(
                      color: AppColors.teacherPrimary),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Initializing Anti-Proxy Engine...',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Locking GPS Geofence & Starting Session for ${widget.courseCode}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 54),
                        const SizedBox(height: AppSpacing.md),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14)),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Try Again',
                          icon: Icons.refresh_rounded,
                          gradient: AppGradients.teacher,
                          onPressed: _startLiveSession,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LIVE pill (animated)
                      AnimatedContainer(
                        duration: AppDurations.medium,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors_rounded,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'LIVE TOTP SESSION ACTIVE',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.courseTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // QR Card with Timer Ring
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: AppDurations.fast,
                              child: _currentQrToken != null
                                  ? QrImageView(
                                      key: ValueKey(_currentQrToken),
                                      data: _currentQrToken!,
                                      version: QrVersions.auto,
                                      size: 230.0,
                                    )
                                  : const SizedBox(
                                      key: ValueKey('qr-loading'),
                                      height: 230,
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: AppDurations.fast,
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    value: _secondsRemaining / 15.0,
                                    strokeWidth: 3,
                                    color: timerColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AnimatedDefaultTextStyle(
                                  duration: AppDurations.fast,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: timerColor,
                                  ),
                                  child: Text(
                                    'Rotates in $_secondsRemaining seconds',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Live Counter gradient card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: AppGradients.teacher,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: AppShadows.brand,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Checked In',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Live Students',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: AppDurations.medium,
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(
                                scale: anim,
                                child:
                                    FadeTransition(opacity: anim, child: child),
                              ),
                              child: Text(
                                '$_checkedInCount',
                                key: ValueKey(_checkedInCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      if (_recentAttendees.isNotEmpty) ...[
                        const SectionHeader('Recent Check-ins'),
                        const SizedBox(height: AppSpacing.sm),
                        ..._recentAttendees.map((attendee) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.successLight,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: AppColors.success, size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attendee['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Reg: ${attendee['regNo']}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const StatusChip(
                                    label: 'PRESENT',
                                    background: AppColors.successLight,
                                    foreground: AppColors.success,
                                    icon: Icons.check_circle_rounded,
                                  ),
                                ],
                              ),
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
