import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_app/core/errors/api_exception.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/endpoints.dart';
import 'package:mobile_app/core/storage/secure_storage.dart';
import 'package:mobile_app/services/app_config.dart';
import 'package:mobile_app/services/device_service.dart';
import 'package:mobile_app/services/face_embedding_service.dart';
import 'package:mobile_app/theme/app_theme.dart';

/// Phase 6 — biometric enrolment.
///
/// Captures _kRequiredSamples distinct face photos, runs each through the
/// 128-D mobilefacenet projector, and posts the resulting `embeddings[]`
/// to `/api/v1/biometrics/enroll-face` together with the device id.
///
/// One-Student × One-Device × One-Face is enforced server-side. The
/// client only collects the raw evidence and surfaces friendly error
/// messages for the obvious failure modes.
class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  static const int _kRequiredSamples = 3;

  CameraController? _cameraController;
  final FaceEmbeddingService _biometrics = FaceEmbeddingService();

  bool _initialising = true;
  bool _busy = false;
  String _statusMessage = 'Centre your face inside the frame.';
  String _errorCode = '';
  final List<String> _capturedPaths = <String>[];
  final List<Face> _capturedFaces = <Face>[];

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
        _initialising = false;
      });
    } catch (e) {
      setState(() {
        _initialising = false;
        _statusMessage = 'Camera unavailable.';
        _errorCode = 'CAMERA_INIT';
      });
    }
  }

  Future<void> _onCapturePressed() async {
    final camera = _cameraController;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    if (_capturedPaths.length >= _kRequiredSamples) return;

    setState(() {
      _busy = true;
      _statusMessage =
          'Capturing sample ${_capturedPaths.length + 1} of $_kRequiredSamples';
      _errorCode = '';
    });

    try {
      final picture = await camera.takePicture();
      final face = await _biometrics.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _statusMessage = 'No face or multiple faces detected.';
        });
        return;
      }
      _capturedPaths.add(picture.path);
      _capturedFaces.add(face);

      if (_capturedPaths.length >= _kRequiredSamples) {
        await _submit();
      } else {
        setState(() {
          _statusMessage = 'Sample ${_capturedPaths.length} captured. '
              'Now tilt your head slightly and capture again.';
        });
      }
    } on DeviceIdUnavailable catch (e) {
      setState(() {
        _statusMessage = e.message;
        _errorCode = 'DEVICE_ID_UNAVAILABLE';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Capture failed: $e';
        _errorCode = 'CAPTURE_FAILED';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _statusMessage = 'Extracting face vectors...';
      _errorCode = '';
    });
    final vectors = await _biometrics.extractMultipleEmbeddings(
      _capturedPaths,
      _capturedFaces,
    );
    if (vectors == null) {
      setState(() {
        _statusMessage = 'Could not extract quality face vectors.';
        _errorCode = 'WEAK_FACE';
      });
      return;
    }

    try {
      final deviceId = await DeviceService.getDeviceId();
      final baseUrl = await AppConfig.getBaseUrl();
      final jwt = await SecureStorage.instance.readAccessToken();
      final client = ApiClient(
        baseUrl: baseUrl,
        accessTokenProvider: () async => jwt,
      );
      await client.post(Endpoints.enrollFace, {
        'deviceId': deviceId,
        'embeddings': vectors,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device & face enrolled successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _statusMessage = _mapApiError(e.code, e.message);
        _errorCode = e.code;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Enrolment failed: $e';
        _errorCode = 'UNKNOWN';
      });
    }
  }

  String _mapApiError(String code, String fallback) {
    switch (code) {
      case 'DEVICE_ALREADY_BOUND':
        return 'This device is already bound to another student. Contact admin.';
      case 'DEVICE_LOCKED':
        return 'Your account is locked. Contact admin.';
      case 'WEAK_FACE':
        return 'Face samples were too low quality. Try better lighting.';
      case 'FACE_NOT_ENROLLED':
        return 'No enrolment found for this account.';
      case 'AUTH_INVALID_CREDENTIALS':
      case 'AUTH_REQUIRED':
        return 'Session expired. Please log in again.';
      default:
        return fallback;
    }
  }

  void _resetForRetry() {
    setState(() {
      _capturedPaths.clear();
      _capturedFaces.clear();
      _statusMessage = 'Centre your face inside the frame.';
      _errorCode = '';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _biometrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialising) {
      return const Scaffold(
        backgroundColor: Colors.black,
        appBar: GradientAppBar(
          title: 'Biometric Registration',
          gradient: AppGradients.primaryDeep,
          showBackButton: true,
        ),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final camera = _cameraController;
    final cameraReady = camera != null && camera.value.isInitialized;
    final progress = _capturedPaths.length;
    final done = progress >= _kRequiredSamples;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const GradientAppBar(
        title: 'Biometric Registration',
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
                  active: _busy,
                  color: _busy ? AppColors.warning : AppColors.success,
                  size: 260,
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
                StepIndicator(
                  labels: const ['Sample 1', 'Sample 2', 'Sample 3'],
                  activeIndex: progress.clamp(0, _kRequiredSamples - 1),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _errorCode.isNotEmpty
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
                const SizedBox(height: AppSpacing.md),
                if (!done)
                  PrimaryButton(
                    label: _busy ? 'Working...' : 'Capture Sample',
                    icon: Icons.camera_alt_rounded,
                    gradient: AppGradients.primary,
                    loading: _busy,
                    expand: true,
                    height: 52,
                    onPressed: _onCapturePressed,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Restart',
                          icon: Icons.refresh_rounded,
                          onPressed: _resetForRetry,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Enrol Now',
                          icon: Icons.fingerprint_rounded,
                          gradient: AppGradients.success,
                          expand: true,
                          height: 52,
                          onPressed: _busy ? null : _submit,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
