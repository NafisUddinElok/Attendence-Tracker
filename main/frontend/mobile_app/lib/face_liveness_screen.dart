// lib/face_liveness_screen.dart
//
// Simple on-device liveness check: opens the front camera, periodically
// captures a still frame, runs ML Kit face detection with eye-open
// classification, and requires the user to blink (open -> closed -> open)
// within a time window. This does NOT verify identity — it only confirms a
// real, live face is in front of the camera (not a static photo).
//
// Returns `true` via Navigator.pop if liveness is confirmed, `false`/null
// if cancelled or timed out.

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

enum _LivenessState { lookingForFace, faceFoundWaitBlink, eyesClosedDetected, verified, failed }

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  CameraController? _controller;
  late final FaceDetector _faceDetector;
  Timer? _captureTimer;
  Timer? _countdownTimer;
  bool _isProcessing = false;
  _LivenessState _state = _LivenessState.lookingForFace;
  String _statusText = 'Position your face in the frame';
  int _secondsElapsed = 0;
  static const int _timeoutSeconds = 15;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) return;

    setState(() => _controller = controller);
    _startTimers();
  }

  void _startTimers() {
    _captureTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _captureAndAnalyze());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed++;
      if (_secondsElapsed >= _timeoutSeconds && _state != _LivenessState.verified) {
        _fail('Timed out. Please try again.');
      }
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;
    if (_state == _LivenessState.verified || _state == _LivenessState.failed) return;

    _isProcessing = true;
    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      // We only needed the file for this one analysis pass — clean it up.
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _state = _LivenessState.lookingForFace;
          _statusText = 'No face detected. Center your face in the frame.';
        });
        return;
      }
      if (faces.length > 1) {
        setState(() => _statusText = 'Only one person should be in frame.');
        return;
      }

      final face = faces.first;
      final leftOpen = face.leftEyeOpenProbability;
      final rightOpen = face.rightEyeOpenProbability;

      if (leftOpen == null || rightOpen == null) {
        setState(() => _statusText = 'Adjust lighting or angle and try again.');
        return;
      }

      final eyesOpen = leftOpen > 0.6 && rightOpen > 0.6;
      final eyesClosed = leftOpen < 0.3 && rightOpen < 0.3;

      if (_state == _LivenessState.lookingForFace) {
        setState(() {
          _state = _LivenessState.faceFoundWaitBlink;
          _statusText = 'Great — now blink your eyes';
        });
      } else if (_state == _LivenessState.faceFoundWaitBlink && eyesClosed) {
        setState(() {
          _state = _LivenessState.eyesClosedDetected;
          _statusText = 'Detected — now open your eyes';
        });
      } else if (_state == _LivenessState.eyesClosedDetected && eyesOpen) {
        _succeed();
      }
    } catch (_) {
      if (mounted) setState(() => _statusText = 'Something went wrong, retrying...');
    } finally {
      _isProcessing = false;
    }
  }

  void _succeed() {
    _captureTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _state = _LivenessState.verified;
      _statusText = 'Verified!';
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  void _fail(String reason) {
    _captureTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _state = _LivenessState.failed;
        _statusText = reason;
      });
    }
  }

  void _retry() {
    setState(() {
      _state = _LivenessState.lookingForFace;
      _statusText = 'Position your face in the frame';
      _secondsElapsed = 0;
    });
    _startTimers();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _countdownTimer?.cancel();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Face Verification')),
      body: Column(
        children: [
          Expanded(
            child: controller == null || !controller.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_state == _LivenessState.verified)
                  const Icon(Icons.check_circle, color: Colors.green, size: 48)
                else if (_state == _LivenessState.failed)
                  const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                if (_state == _LivenessState.failed)
                  ElevatedButton(onPressed: _retry, child: const Text('Try Again'))
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}