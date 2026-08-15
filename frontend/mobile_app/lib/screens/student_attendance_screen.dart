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

enum VerificationStep { faceScan, qrScan, verifying, success, failed }

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final _storage = const FlutterSecureStorage();

  // Camera & Face Service
  CameraController? _cameraController;
  final FaceEmbeddingService _biometricService = FaceEmbeddingService();

  // Verification State Variables
  VerificationStep _currentStep = VerificationStep.faceScan;
  String _statusMessage = 'Look directly into the camera';
  String _errorMessage = '';

  List<double>? _extractedEmbedding;
  bool _livenessPassed = false;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _initFaceCamera();
  }

  // -------------------------------------------------------------
  // STEP 1 & 2: Front Camera & Face Liveness Verification
  // -------------------------------------------------------------
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
    if (_isProcessingFrame || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessingFrame = true;
      _statusMessage = 'Analyzing facial biometrics & liveness...';
    });

    try {
      final picture = await _cameraController!.takePicture();

      // 1. Detect single face
      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _statusMessage = '⚠️ No face detected or multiple faces in view.';
          _isProcessingFrame = false;
        });
        return;
      }

      // 2. Check eyes open quality (Liveness heuristic)
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;

      if (leftEye < 0.5 || rightEye < 0.5) {
        setState(() {
          _statusMessage = '⚠️ Please open both eyes clearly.';
          _isProcessingFrame = false;
        });
        return;
      }

      // 3. Extract 192D Embedding Vector
      final embedding = await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null || embedding.isEmpty) {
        setState(() {
          _statusMessage = '⚠️ Face vector extraction failed. Try again.';
          _isProcessingFrame = false;
        });
        return;
      }

      _extractedEmbedding = embedding;
      _livenessPassed = true;

      // Dispose selfie camera before opening QR Scanner
      await _cameraController?.dispose();
      _cameraController = null;

      setState(() {
        _currentStep = VerificationStep.qrScan;
        _isProcessingFrame = false;
        _statusMessage = 'Point camera at Teacher\'s Live QR Code';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Face verification error: $e';
        _isProcessingFrame = false;
      });
    }
  }

  // -------------------------------------------------------------
  // STEP 3, 4 & 5: QR Code Scan + GPS + Hardware Binding Submission
  // -------------------------------------------------------------
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
      // 1. Parse QR JSON Payload { sessionId, token, ts }
      final Map<String, dynamic> qrData = jsonDecode(rawCode);
      final String sessionId = qrData['sessionId'];
      final String token = qrData['token'];

      // 2. Capture Real GPS & Mock Location Status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Capture Hardware Device UUID
      final String deviceId = await DeviceService.getDeviceId();

      // 4. Submit to Backend Verification Pipeline
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
          _statusMessage = responseBody['message'] ?? 'Attendance marked successfully!';
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

  // -------------------------------------------------------------
  // UI BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Step Progress Indicator
          Container(
            color: Colors.indigo.shade900,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStepBadge('1. Face', _currentStep == VerificationStep.faceScan),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                _buildStepBadge('2. QR Scan', _currentStep == VerificationStep.qrScan),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                _buildStepBadge('3. Verified', _currentStep == VerificationStep.success),
              ],
            ),
          ),

          // Main Viewport Area
          Expanded(child: _buildMainView()),

          // Bottom Control Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (_currentStep == VerificationStep.faceScan) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingFrame ? null : _captureAndVerifyFace,
                      icon: const Icon(Icons.camera),
                      label: Text(_isProcessingFrame ? 'Processing...' : 'Verify Face & Proceed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (_currentStep == VerificationStep.failed) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = VerificationStep.faceScan;
                        _statusMessage = 'Look directly into the camera';
                      });
                      _initFaceCamera();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
                if (_currentStep == VerificationStep.success) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done & Go Back'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        color: isActive ? Colors.greenAccent : Colors.white60,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildMainView() {
    switch (_currentStep) {
      case VerificationStep.faceScan:
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            CameraPreview(_cameraController!),
            Container(
              width: 250,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ],
        );

      case VerificationStep.qrScan:
        return MobileScanner(
          onDetect: _onQrCodeScanned,
        );

      case VerificationStep.verifying:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Running Anti-Proxy Checks...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );

      case VerificationStep.success:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 90),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );

      case VerificationStep.failed:
        return const Center(
          child: Icon(Icons.cancel, color: Colors.redAccent, size: 90),
        );
    }
  }
}