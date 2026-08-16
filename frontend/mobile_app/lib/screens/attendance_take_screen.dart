import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/endpoints.dart';
import 'package:mobile_app/core/storage/secure_storage.dart';
import 'package:mobile_app/services/device_service.dart';
import 'package:mobile_app/services/face_embedding_service.dart';
import 'package:mobile_app/theme/app_theme.dart';

/// Phase 6 — dedicated "take a photo to mark attendance" page.
///
/// Single flow: open camera -> capture one frame -> detect one face ->
/// extract 128-D embedding -> resolve device id + GPS + mock flag ->
/// POST `/api/v1/attendance/verify`.
///
/// No QR scan, no liveness dance. Anti-proxy is enforced server-side
/// (device binding + geofence + mock-location + face cosine).
class AttendanceTakeScreen extends StatefulWidget {
  const AttendanceTakeScreen({
    super.key,
    required this.sessionId,
    required this.apiClient,
  });

  final String sessionId;

  /// Pre-wired ApiClient (with access token provider set up).
  final ApiClient apiClient;

  @override
  State<AttendanceTakeScreen> createState() => _AttendanceTakeScreenState();
}

enum _Step { ready, capturing, verifying, success, failed }

class _AttendanceTakeScreenState extends State<AttendanceTakeScreen> {
  CameraController? _cameraController;
  final FaceEmbeddingService _biometrics = FaceEmbeddingService();

  _Step _step = _Step.ready;
  String _statusMessage = 'Center your face inside the frame.';
  String _errorMessage = '';
  String _errorCode = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _biometrics.init();
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
      });
    } catch (e) {
      setState(() {
        _step = _Step.failed;
        _statusMessage = 'Camera unavailable.';
        _errorMessage = e.toString();
        _errorCode = 'CAMERA_INIT';
      });
    }
  }

  Future<void> _onCapturePressed() async {
    final camera = _cameraController;
    if (_step != _Step.ready || camera == null || !camera.value.isInitialized) {
      return;
    }
    setState(() {
      _step = _Step.capturing;
      _statusMessage = 'Capturing photo...';
      _errorMessage = '';
      _errorCode = '';
    });

    try {
      final picture = await camera.takePicture();
      final face = await _biometrics.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _step = _Step.ready;
          _statusMessage = 'No face or multiple faces detected.';
        });
        return;
      }
      final embedding = await _biometrics.extractFaceEmbedding(
        picture.path,
        face,
      );
      if (embedding == null) {
        setState(() {
          _step = _Step.ready;
          _statusMessage = 'Face extraction failed. Try again.';
        });
        return;
      }

      setState(() {
        _step = _Step.verifying;
        _statusMessage = 'Verifying device, location & face...';
      });

      final deviceId = await DeviceService.getDeviceId();
      final position = await _resolvePosition();
      final result = await widget.apiClient.post(Endpoints.verifyAttendance, {
        'sessionId': widget.sessionId,
        'deviceId': deviceId,
        'lat': position.latitude,
        'lng': position.longitude,
        'isMockLocation': position.isMocked,
        'faceEmbedding': embedding,
      });
      final Map<String, dynamic> body =
          result is Map<String, dynamic> ? result : <String, dynamic>{};
      setState(() {
        _step = _Step.success;
        _statusMessage =
            (body['message'] as String?) ?? 'Attendance marked successfully.';
      });
    } on ApiException catch (e) {
      setState(() {
        _step = _Step.failed;
        _statusMessage = e.message;
        _errorMessage = e.message;
        _errorCode = e.code;
      });
    } on DeviceIdUnavailable catch (e) {
      setState(() {
        _step = _Step.failed;
        _statusMessage = e.message;
        _errorMessage = e.message;
        _errorCode = 'DEVICE_ID_UNAVAILABLE';
      });
    } catch (e) {
      setState(() {
        _step = _Step.failed;
        _statusMessage = 'Verification failed.';
        _errorMessage = e.toString();
        _errorCode = 'UNKNOWN';
      });
    }
  }

  Future<Position> _resolvePosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException(
        code: 'LOCATION_DENIED',
        message: 'Location permission permanently denied. Enable in Settings.',
        status: 403,
      );
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _biometrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    final cameraReady = camera != null && camera.value.isInitialized;
    final busy = _step == _Step.capturing || _step == _Step.verifying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const GradientAppBar(
        title: 'Mark Attendance',
        gradient: AppGradients.primaryDeep,
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (cameraReady)
                  CameraPreview(camera)
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                PulseFrame(
                  active: busy,
                  color: busy ? AppColors.warning : AppColors.success,
                  size: 250,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl),
              ),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _step == _Step.failed
                        ? AppColors.danger
                        : AppColors.textPrimary,
                  ),
                ),
                if (_errorCode.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _errorCode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (_errorMessage.isNotEmpty && _errorCode.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_step == _Step.ready)
                  PrimaryButton(
                    label: busy ? 'Working...' : 'Capture & Verify',
                    icon: Icons.camera_alt_rounded,
                    gradient: AppGradients.primary,
                    expand: true,
                    height: 52,
                    onPressed: busy ? null : _onCapturePressed,
                  ),
                if (_step == _Step.failed)
                  PrimaryButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    color: AppColors.danger,
                    expand: true,
                    height: 48,
                    onPressed: () => setState(() {
                      _step = _Step.ready;
                      _statusMessage = 'Center your face inside the frame.';
                      _errorMessage = '';
                      _errorCode = '';
                    }),
                  ),
                if (_step == _Step.success)
                  PrimaryButton(
                    label: 'Done',
                    icon: Icons.check_circle_rounded,
                    gradient: AppGradients.success,
                    expand: true,
                    height: 52,
                    onPressed: () => Navigator.pop(context, true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight helper for callers: build an `ApiClient` wired to the
/// bearer token stored by the auth feature.
Future<ApiClient> buildAttendanceApiClient() async {
  final client = ApiClient();
  client.setAccessTokenProvider(() => SecureStorage.instance.readAccessToken());
  return client;
}
