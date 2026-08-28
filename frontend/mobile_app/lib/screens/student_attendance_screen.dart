import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/device_service.dart';
import '../services/face_embedding_service.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';

enum VerificationStep { faceScan, qrScan, verifying, success, failed }

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final _storage = const FlutterSecureStorage();

  CameraController? _cameraController;
  final FaceEmbeddingService _biometricService = FaceEmbeddingService();

  VerificationStep _currentStep = VerificationStep.faceScan;
  String _statusMessage = 'Look directly into the camera';
  String _errorMessage = '';

  List<double>? _extractedEmbedding;
  bool _livenessPassed = false;
  bool _isProcessingFrame = false;

  static const _steps = ['Face', 'QR', 'Verify'];

  int get _displayStep {
    switch (_currentStep) {
      case VerificationStep.faceScan:
        return 0;
      case VerificationStep.qrScan:
        return 1;
      case VerificationStep.verifying:
        return 2;
      case VerificationStep.success:
        return 3;
      case VerificationStep.failed:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _initFaceCamera();
  }

  Future<void> _initFaceCamera() async {
    await _biometricService.init();
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndVerifyFace() async {
    if (_isProcessingFrame ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) return;
    setState(() {
      _isProcessingFrame = true;
      _statusMessage = 'Analyzing facial biometrics & liveness...';
    });

    try {
      final picture = await _cameraController!.takePicture();

      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _statusMessage = 'No face detected or multiple faces in view.';
          _isProcessingFrame = false;
        });
        return;
      }

      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;

      if (leftEye < 0.5 || rightEye < 0.5) {
        setState(() {
          _statusMessage = 'Please open both eyes clearly.';
          _isProcessingFrame = false;
        });
        return;
      }

      final embedding =
          await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null || embedding.isEmpty) {
        setState(() {
          _statusMessage = '⚠️ Face Data extraction failed. Try again.';
          _isProcessingFrame = false;
        });
        return;
      }

      _extractedEmbedding = embedding;
      _livenessPassed = true;

      await _cameraController?.dispose();
      _cameraController = null;

      setState(() {
        _currentStep = VerificationStep.qrScan;
        _isProcessingFrame = false;
        _statusMessage = "Point camera at Teacher's Live QR Code";
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Face verification error: $e';
        _isProcessingFrame = false;
      });
    }
  }

  Future<void> _onQrCodeScanned(BarcodeCapture capture) async {
    if (_currentStep != VerificationStep.qrScan) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawCode = barcodes.first.rawValue;
    if (rawCode == null || rawCode.isEmpty) return;

    setState(() {
      _currentStep = VerificationStep.verifying;
      _statusMessage = 'Verifying Location, Device & TOTP Token...';
    });

    try {
      final Map<String, dynamic> qrData = jsonDecode(rawCode);
      final String sessionId = qrData['sessionId'];
      final String token = qrData['token'];

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final String deviceId = await DeviceService.getDeviceId();

      final baseUrl = await AppConfig.getBaseUrl();
      final jwtToken = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$baseUrl/api/attendance/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'token': token,
          'deviceId': deviceId,
          'lat': position.latitude,
          'lng': position.longitude,
          'isMockLocation': position.isMocked,
          'livenessPassed': _livenessPassed,
          'faceEmbedding': _extractedEmbedding,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _currentStep = VerificationStep.success;
          _statusMessage =
              responseBody['message'] ?? 'Attendance marked successfully!';
        });
      } else {
        setState(() {
          _currentStep = VerificationStep.failed;
          _errorMessage = responseBody['message'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = VerificationStep.failed;
        _errorMessage = 'Invalid QR Code or network error: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _biometricService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: GradientAppBar(
        title: 'Mark Attendance',
        gradient: AppGradients.primaryDeep,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Step progress strip
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.lg),
            child: StepIndicator(
              labels: _steps,
              activeIndex:
                  _currentStep == VerificationStep.failed ? 0 : _displayStep,
            ),
          ),

          Expanded(child: _buildMainView()),

          // Bottom Control Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl)),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                if (_currentStep == VerificationStep.faceScan) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _isProcessingFrame
                        ? 'Processing...'
                        : 'Verify Face & Proceed',
                    icon: Icons.camera_alt_rounded,
                    gradient: AppGradients.primary,
                    loading: _isProcessingFrame,
                    expand: true,
                    height: 52,
                    onPressed: _captureAndVerifyFace,
                  ),
                ],
                if (_currentStep == VerificationStep.failed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    color: AppColors.danger,
                    expand: true,
                    height: 48,
                    onPressed: () {
                      setState(() {
                        _currentStep = VerificationStep.faceScan;
                        _statusMessage = 'Look directly into the camera';
                      });
                      _initFaceCamera();
                    },
                  ),
                ],
                if (_currentStep == VerificationStep.success) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Done & Go Back',
                    icon: Icons.check_circle_rounded,
                    gradient: AppGradients.success,
                    expand: true,
                    height: 52,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    switch (_currentStep) {
      case VerificationStep.faceScan:
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            CameraPreview(_cameraController!),
            PulseFrame(
              active: _isProcessingFrame,
              color: _isProcessingFrame ? AppColors.warning : AppColors.success,
              size: 250,
            ),
          ],
        );

      case VerificationStep.qrScan:
        return Stack(
          children: [
            MobileScanner(onDetect: _onQrCodeScanned),
            // QR frame overlay
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.warning, width: 3),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
            ),
          ],
        );

      case VerificationStep.verifying:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.warning),
              SizedBox(height: AppSpacing.md),
              Text(
                'Running Anti-Proxy Checks...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

      case VerificationStep.success:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppGradients.success,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.brand,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );

      case VerificationStep.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.brand,
                ),
                child: const Icon(Icons.cancel_rounded,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Verification Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
    }
  }
}
