import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/device_service.dart';
import '../services/face_embedding_service.dart';
import '../services/app_config.dart';

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
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Detecting face & checking quality...';
    });

    try {
      final picture = await _cameraController!.takePicture();

      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) {
        setState(() {
          _statusMessage = 'No face or multiple faces detected. Keep only your face visible.';
          _isProcessing = false;
        });
        return;
      }

      if ((face.leftEyeOpenProbability ?? 1.0) < 0.6 || (face.rightEyeOpenProbability ?? 1.0) < 0.6) {
        setState(() {
          _statusMessage = 'Please keep both eyes clearly open.';
          _isProcessing = false;
        });
        return;
      }

      setState(() => _statusMessage = 'Extracting facial vector embedding...');

      final embedding = await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null) {
        setState(() {
          _statusMessage = 'Failed to extract face vector. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      final deviceId = await DeviceService.getDeviceId();

      setState(() => _statusMessage = 'Securing biometrics on server...');
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
          const SnackBar(
            content: Text('✅ Device & Face registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _statusMessage = err['message'] ?? 'Registration failed.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during registration: $e';
        _isProcessing = false;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Biometric Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cameraController!),
                Container(
                  width: 260,
                  height: 340,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing ? Colors.amber : Colors.greenAccent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(160),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _statusMessage.contains('Error') || _statusMessage.contains('No face')
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _captureAndRegister,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Register Device & Face',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}