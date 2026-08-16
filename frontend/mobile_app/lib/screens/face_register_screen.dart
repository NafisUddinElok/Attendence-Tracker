import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/device_service.dart';
import '../services/face_embedding_service.dart';
import '../services/app_config.dart';

enum _AngleId { front, left, right }

class _AngleStep {
  final _AngleId id;
  final String label;
  final String instruction;
  List<double>? embedding;

  _AngleStep({required this.id, required this.label, required this.instruction});
}

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cameraController;
  final FaceEmbeddingService _biometricService = FaceEmbeddingService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Guided 3-angle capture — front, slight-left, slight-right. Capturing
  // multiple angles both improves real-world match accuracy (the actual
  // problem this solves: a single frontal photo is a weak reference when
  // students show up at slightly different angles/lighting every day) and
  // reads as a polished onboarding step rather than a one-shot form.
  //
  // Note on left/right: ML Kit's headEulerAngleY sign convention combined
  // with front-camera mirroring can appear flipped on some devices. The
  // on-screen live instruction is authoritative — a student just turns
  // whichever way makes the guide turn green, regardless of the label.
  late final List<_AngleStep> _steps = [
    _AngleStep(id: _AngleId.front, label: 'Front', instruction: 'Look straight at the camera'),
    _AngleStep(id: _AngleId.left, label: 'Slight left', instruction: 'Slowly turn your head slightly to the left'),
    _AngleStep(id: _AngleId.right, label: 'Slight right', instruction: 'Slowly turn your head slightly to the right'),
  ];
  int _currentIndex = 0;

  bool _isProcessing = false;
  bool _isSubmitting = false;
  String _statusMessage = 'Position your face in the frame';
  Color _guideColor = Colors.amber;

  Timer? _guideTimer;
  int _stableGoodFrames = 0;
  static const int _framesNeededForCapture = 2; // ~2 * 700ms ≈ 1.4s held steady

  // Re-entrancy guard for the guide-loop sampler. _sampleGuidance() takes a
  // real photo (takePicture()) which regularly runs longer than the 700ms
  // timer tick. Without this guard, the next tick fires while the previous
  // takePicture() is still in flight, the camera plugin throws
  // "capture already active", _sampleGuidance()'s catch block turns that
  // into an "ok: false", and _stableGoodFrames keeps getting reset to 0 —
  // so a perfectly still, perfectly straight face can never accumulate two
  // good frames in a row and registration looks stuck on "detecting"
  // forever. This was the actual cause of straight/front pose never
  // completing.
  bool _isSampling = false;

  _AngleStep get _current => _steps[_currentIndex];
  bool get _allCaptured => _steps.every((s) => s.embedding != null);

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
    if (!mounted) return;
    setState(() {});
    _startGuideLoop();
  }

  /// Periodically samples the camera and gives live feedback (border color
  /// + specific reason) for the *current* angle step, auto-capturing once
  /// the pose has been held correctly for ~1.5s.
  void _startGuideLoop() {
    _guideTimer?.cancel();
    _guideTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!mounted || _isProcessing || _isSubmitting || _allCaptured) return;
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      // Skip this tick entirely if the previous sample's takePicture() is
      // still running — letting them overlap is what caused the stuck
      // "not detecting" behaviour.
      if (_isSampling) return;

      _isSampling = true;
      ({bool ok, String message}) result;
      try {
        result = await _sampleGuidance();
      } finally {
        _isSampling = false;
      }
      if (!mounted || _allCaptured) return;

      setState(() {
        _statusMessage = result.message;
        _guideColor = result.ok ? Colors.greenAccent : Colors.amber;
      });

      if (result.ok) {
        _stableGoodFrames++;
        if (_stableGoodFrames >= _framesNeededForCapture) {
          _stableGoodFrames = 0;
          await _captureCurrentAngle();
        }
      } else {
        _stableGoodFrames = 0;
      }
    });
  }

  Future<({bool ok, String message})> _sampleGuidance() async {
    try {
      final picture = await _cameraController!.takePicture().timeout(const Duration(seconds: 3));
      final face = await _biometricService.detectSingleFace(picture.path);

      if (face == null) {
        return (ok: false, message: 'No face detected — center your face in the frame');
      }

      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      if (leftEye < 0.5 || rightEye < 0.5) {
        return (ok: false, message: 'Keep both eyes open');
      }

      // Size check (too close / too far) — compare face box to image width.
      final bytes = await File(picture.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && decoded.width > 0) {
        final ratio = face.boundingBox.width / decoded.width;
        if (ratio < 0.22) return (ok: false, message: 'Move closer');
        if (ratio > 0.78) return (ok: false, message: 'Move back a little');
      }

      // Slightly widened from the original ±12 / 15-45 windows — those were
      // tight enough that a genuinely straight, still face could sit just
      // outside the accepted range on some devices and never register as
      // "ok". This keeps the pose meaningfully distinct per step while
      // giving real students realistic margin to land inside it.
      final angleY = face.headEulerAngleY ?? 0;
      switch (_current.id) {
        case _AngleId.front:
          if (angleY.abs() > 18) {
            return (ok: false, message: _current.instruction);
          }
          break;
        case _AngleId.left:
          if (angleY < 10 || angleY > 50) {
            return (ok: false, message: _current.instruction);
          }
          break;
        case _AngleId.right:
          if (angleY > -10 || angleY < -50) {
            return (ok: false, message: _current.instruction);
          }
          break;
      }

      return (ok: true, message: 'Hold still...');
    } catch (_) {
      return (ok: false, message: _current.instruction);
    }
  }

  Future<void> _captureCurrentAngle() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing ${_current.label.toLowerCase()}...';
    });

    try {
      final picture = await _cameraController!.takePicture();
      final face = await _biometricService.detectSingleFace(picture.path);

      if (face == null) {
        _resumeGuiding('No face detected. Keep only your face visible.');
        return;
      }

      final embedding = await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null) {
        _resumeGuiding('Failed to read that angle. Try again.');
        return;
      }

      setState(() {
        _current.embedding = embedding;
        _isProcessing = false;
      });

      if (_allCaptured) {
        _guideTimer?.cancel();
        await _submitRegistration();
      } else {
        setState(() {
          _currentIndex++;
          _statusMessage = _current.instruction;
          _guideColor = Colors.amber;
        });
      }
    } catch (e) {
      _resumeGuiding('Capture error — try again.');
    }
  }

  void _resumeGuiding(String message) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _isProcessing = false;
      _guideColor = Colors.amber;
    });
    _stableGoodFrames = 0;
  }

  /// Lets the student redo just one already-captured angle instead of
  /// starting the whole flow over.
  void _redoAngle(int index) {
    setState(() {
      _steps[index].embedding = null;
      _currentIndex = index;
      _statusMessage = _steps[index].instruction;
      _guideColor = Colors.amber;
      _stableGoodFrames = 0;
    });
    _startGuideLoop();
  }

  /// Combines the 3 per-angle embeddings into a single registered
  /// reference vector: normalize each to unit length (cosine similarity is
  /// scale-invariant, so this weights each angle equally regardless of
  /// lighting-driven magnitude differences), average them, then
  /// re-normalize the result.
  List<double> _combineEmbeddings() {
    final vectors = _steps.map((s) => s.embedding!).toList();
    final dim = vectors.first.length;

    List<double> normalize(List<double> v) {
      final mag = _vectorMagnitude(v);
      if (mag == 0) return v;
      return v.map((x) => x / mag).toList();
    }

    final normalized = vectors.map(normalize).toList();
    final avg = List<double>.filled(dim, 0.0);
    for (final v in normalized) {
      for (int i = 0; i < dim; i++) {
        avg[i] += v[i] / normalized.length;
      }
    }
    return normalize(avg);
  }

  double _vectorMagnitude(List<double> v) {
    double sumSq = 0;
    for (final x in v) {
      sumSq += x * x;
    }
    return sumSq <= 0 ? 0 : sqrt(sumSq);
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Combining captures & securing biometrics on server...';
    });

    try {
      final combinedEmbedding = _combineEmbeddings();
      final deviceId = await DeviceService.getDeviceId();

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
          'faceEmbedding': combinedEmbedding,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
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
          _statusMessage = err['message'] ?? 'Registration failed. Please try again.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Couldn't reach the server. Check your connection and try again.";
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
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
          // Progress dots — tap a completed one to redo just that angle.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final step = _steps[i];
                final isDone = step.embedding != null;
                final isCurrent = i == _currentIndex && !isDone;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: isDone ? () => _redoAngle(i) : null,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isDone
                              ? Colors.greenAccent
                              : (isCurrent ? Colors.amber : Colors.white24),
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.black, size: 18)
                              : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.label,
                          style: TextStyle(
                            color: isDone ? Colors.greenAccent : Colors.white70,
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isDone)
                          const Text('tap to redo', style: TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
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
                      color: _isProcessing || _isSubmitting ? Colors.amber : _guideColor,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(160),
                  ),
                ),
                if (!_allCaptured)
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _current.instruction,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
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
                    color: _statusMessage.toLowerCase().contains('fail') ||
                            _statusMessage.toLowerCase().contains("couldn't") ||
                            _statusMessage.toLowerCase().contains('error')
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSubmitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CircularProgressIndicator(),
                  )
                else if (!_isProcessing)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _captureCurrentAngle,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text('Capture ${_current.label.toLowerCase()} manually'),
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