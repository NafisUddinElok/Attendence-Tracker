import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/device_service.dart';
import '../services/face_embedding_service.dart';
import '../services/app_config.dart';
import '../theme/app_theme.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cameraController;
  final FaceEmbeddingService _biometricService = FaceEmbeddingService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isProcessing = false;
  String _statusMessage = 'Place your face inside the circle';
  int _currentStep = 0;

  static const _steps = ['Detect', 'Liveness', 'Embed', 'Register'];

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
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

  Future<void> _captureAndRegister() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Detecting face & checking quality...';
      _currentStep = 0;
    });

    setState(() => _currentStep = 1);

    try {
      final picture = await _cameraController!.takePicture();

      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _statusMessage = 'No face or multiple faces detected. Keep only your face visible.';
          _isProcessing = false;
          _currentStep = 0;
        });
        return;
      }

      if ((face.leftEyeOpenProbability ?? 1.0) < 0.6 ||
          (face.rightEyeOpenProbability ?? 1.0) < 0.6) {
        setState(() {
          _statusMessage = 'Please keep both eyes clearly open.';
          _isProcessing = false;
          _currentStep = 1;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Extracting facial vector embedding...';
        _currentStep = 2;
      });

      final embedding =
          await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null) {
        setState(() {
          _statusMessage = 'Failed to extract face vector. Please try again.';
          _isProcessing = false;
          _currentStep = 2;
        });
        return;
      }

      final deviceId = await DeviceService.getDeviceId();

      setState(() {
        _statusMessage = 'Securing biometrics on server...';
        _currentStep = 3;
      });

      final baseUrl = await AppConfig.getBaseUrl();
      final token = await _storage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register-biometrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'faceEmbedding': embedding,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Device & Face registered successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _statusMessage = err['message'] ?? 'Registration failed.';
          _isProcessing = false;
          _currentStep = 0;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during registration: $e';
        _isProcessing = false;
        _currentStep = 0;
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const GradientAppBar(
          title: 'Biometric Registration',
          gradient: AppGradients.primaryDeep,
          showBackButton: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isError = _statusMessage.contains('Error') ||
        _statusMessage.contains('No face');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: GradientAppBar(
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
                CameraPreview(_cameraController!),
                // Pulse frame overlay
                PulseFrame(
                  isActive: _isProcessing,
                  color: _isProcessing ? AppColors.warning : AppColors.success,
                  size: const Size(260, 340),
                  borderRadius: 160,
                  borderWidth: 3,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepIndicator(
                  labels: _steps,
                  activeIndex: _currentStep,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isError
                        ? AppColors.danger
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: _isProcessing
                      ? 'Processing...'
                      : 'Register Device & Face',
                  icon: Icons.fingerprint_rounded,
                  gradient: AppGradients.success,
                  loading: _isProcessing,
                  expand: true,
                  height: 52,
                  onPressed: _captureAndRegister,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}