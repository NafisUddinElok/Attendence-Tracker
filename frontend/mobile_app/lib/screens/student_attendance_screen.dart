import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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

  // True when the *last* failure was a network/connectivity problem (never
  // reached the server, or timed out) rather than the server actually
  // rejecting the attempt. This changes what "retry" should do: a network
  // blip should just resubmit the exact same payload, not force the
  // student through face capture + QR scan again.
  bool _isNetworkFailure = false;

  List<double>? _extractedEmbedding;
  bool _livenessPassed = false;
  bool _isProcessingFrame = false;

  // Auto-capture: samples the camera periodically while on the face-scan
  // step and auto-triggers verification once a good, stable frame has been
  // seen for ~1 second — no manual button tap needed. The manual button
  // still exists as a fallback (e.g. lighting makes auto-detection flaky).
  Timer? _autoCaptureTimer;
  int _stableGoodFrames = 0;
  static const int _framesNeededForAutoCapture = 2; // ~2 * 650ms ≈ 1.3s
  bool _autoCaptureArmed = true;

  // GPS is pre-fetched in parallel with the face scan (instead of only
  // being requested after the QR scan) so there's no dead time waiting on
  // a location fix once the student is ready to submit.
  Position? _prefetchedPosition;
  Future<Position>? _locationFetchInFlight;

  // Cached last-submitted payload so a network-failure retry can resubmit
  // without re-running face capture or re-scanning the QR code.
  Map<String, dynamic>? _lastQrData;
  Position? _lastPosition;
  String? _lastDeviceId;
  String? _lastScannedBleUuid;

  @override
  void initState() {
    super.initState();
    _initFaceCamera();
    _prefetchLocation(); // runs in parallel with face scan, not after QR scan
  }

  // -------------------------------------------------------------
  // GPS pre-fetch (runs alongside the face-scan step)
  // -------------------------------------------------------------
  Future<void> _prefetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return; // surfaced again (and re-requested) at the QR step if still missing
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _prefetchedPosition = position;
    } catch (_) {
      // Silent — _getLocation() below falls back to a fresh fetch if this failed.
    }
  }

  /// Returns the pre-fetched position if we have one, otherwise fetches a
  /// fresh one (with permission handling) right now.
  Future<Position> _getLocation() async {
    if (_prefetchedPosition != null) return _prefetchedPosition!;

    if (_locationFetchInFlight != null) return _locationFetchInFlight!;

    final future = () async {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    }();

    _locationFetchInFlight = future;
    return future;
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
    if (!mounted) return;
    setState(() {});
    _startAutoCaptureLoop();
  }

  /// Periodically samples the camera while on the face-scan step. Once a
  /// well-framed, both-eyes-open single face has been seen for a couple of
  /// consecutive samples in a row, it auto-triggers the same capture path
  /// as the manual button — the student never has to tap anything if
  /// they're already holding still and framed correctly.
  void _startAutoCaptureLoop() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
      if (!mounted || !_autoCaptureArmed) return;
      if (_currentStep != VerificationStep.faceScan) return;
      if (_isProcessingFrame) return;
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;

      final isGoodFrame = await _sampleFrameQuality();
      if (!mounted || _currentStep != VerificationStep.faceScan) return;

      if (isGoodFrame) {
        _stableGoodFrames++;
        setState(() => _statusMessage = _stableGoodFrames >= _framesNeededForAutoCapture
            ? 'Hold still... capturing'
            : 'Good — hold still');
        if (_stableGoodFrames >= _framesNeededForAutoCapture) {
          _autoCaptureArmed = false; // prevent double-trigger while capturing
          await _captureAndVerifyFace();
        }
      } else {
        _stableGoodFrames = 0;
      }
    });
  }

  /// Cheap-ish quality sample used only to decide whether to auto-trigger —
  /// the actual capture-and-verify path takes its own fresh picture.
  Future<bool> _sampleFrameQuality() async {
    try {
      final picture = await _cameraController!.takePicture();
      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) return false;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      return leftEye >= 0.5 && rightEye >= 0.5;
    } catch (_) {
      return false;
    }
  }

  Future<void> _captureAndVerifyFace() async {
    if (_isProcessingFrame || _cameraController == null || !_cameraController!.value.isInitialized) return;

    _autoCaptureTimer?.cancel();
    setState(() {
      _isProcessingFrame = true;
      _statusMessage = 'Analyzing facial biometrics & liveness...';
    });

    try {
      final picture = await _cameraController!.takePicture();

      // 1. Detect single face
      final face = await _biometricService.detectSingleFace(picture.path);
      if (face == null) {
        _resumeAutoCapture('No face detected, or more than one face in view. Make sure only your face is visible.');
        return;
      }

      // 2. Check eyes open quality (Liveness heuristic)
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;

      if (leftEye < 0.5 || rightEye < 0.5) {
        _resumeAutoCapture('Please keep both eyes open and look at the camera.');
        return;
      }

      // 3. Extract 192D Embedding Vector
      final embedding = await _biometricService.extractFaceEmbedding(picture.path, face);
      if (embedding == null || embedding.isEmpty) {
        _resumeAutoCapture("Couldn't read your face clearly — try better lighting and hold still.");
        return;
      }

      _extractedEmbedding = embedding;
      _livenessPassed = true;

      // Dispose selfie camera before opening QR Scanner
      await _cameraController?.dispose();
      _cameraController = null;
      _autoCaptureTimer?.cancel();

      setState(() {
        _currentStep = VerificationStep.qrScan;
        _isProcessingFrame = false;
        _statusMessage = "Point camera at teacher's live QR code";
      });
    } catch (e) {
      _resumeAutoCapture("Couldn't process the camera image. Try again.");
    }
  }

  void _resumeAutoCapture(String message) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _isProcessingFrame = false;
    });
    _stableGoodFrames = 0;
    _autoCaptureArmed = true;
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
      _statusMessage = 'Reading QR code...';
    });

    try {
      // 1. Parse QR JSON Payload { sessionId, token, bleUuid }
      final Map<String, dynamic> qrData = jsonDecode(rawCode);
      final String? expectedBleUuid = qrData['bleUuid'];

      // 2. GPS — usually already available from the pre-fetch that started
      // back when the face scan began, so this resolves instantly.
      setState(() => _statusMessage = 'Getting your location...');
      final Position position = await _getLocation();

      // 3. Capture Hardware Device UUID
      final String deviceId = await DeviceService.getDeviceId();

      // 3b. If this session opted into Bluetooth proximity checking, scan
      // for the teacher's beacon before submitting. If the session didn't
      // enable BLE, expectedBleUuid is null and we skip this entirely.
      String? scannedBleUuid;
      if (expectedBleUuid != null && expectedBleUuid.isNotEmpty) {
        setState(() => _statusMessage = 'Scanning for classroom Bluetooth beacon...');
        scannedBleUuid = await _scanForBleBeacon(expectedBleUuid);
      }

      await _submitVerification(
        qrData: qrData,
        position: position,
        deviceId: deviceId,
        scannedBleUuid: scannedBleUuid,
      );
    } catch (e) {
      setState(() {
        _currentStep = VerificationStep.failed;
        _isNetworkFailure = false;
        _errorMessage = 'That QR code could not be read. Point the camera at the live QR code and try again.';
      });
    }
  }

  /// Submits (or resubmits) the verification payload. Split out from
  /// _onQrCodeScanned so a network-failure retry can call this directly
  /// with the cached payload, without re-scanning the QR or redoing the
  /// face capture.
  Future<void> _submitVerification({
    required Map<String, dynamic> qrData,
    required Position position,
    required String deviceId,
    String? scannedBleUuid,
  }) async {
    // Cache in case this attempt fails on the network and needs a retry.
    _lastQrData = qrData;
    _lastPosition = position;
    _lastDeviceId = deviceId;
    _lastScannedBleUuid = scannedBleUuid;

    setState(() {
      _currentStep = VerificationStep.verifying;
      _statusMessage = 'Verifying location, device & TOTP token...';
    });

    final requestBody = jsonEncode({
      'sessionId': qrData['sessionId'],
      'token': qrData['token'],
      'deviceId': deviceId,
      'lat': position.latitude,
      'lng': position.longitude,
      'isMockLocation': position.isMocked,
      'livenessPassed': _livenessPassed,
      'faceEmbedding': _extractedEmbedding,
      'scannedBleUuid': scannedBleUuid,
    });

    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final jwtToken = await _storage.read(key: 'jwt_token');
      final uri = Uri.parse('$baseUrl/api/attendance/verify');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      };

      http.Response response;
      try {
        response = await http.post(uri, headers: headers, body: requestBody).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        if (!mounted) return;
        setState(() => _statusMessage = 'Connection is slow, retrying...');
        response = await http.post(uri, headers: headers, body: requestBody).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return;

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _currentStep = VerificationStep.success;
          _statusMessage = responseBody['message'] ?? 'Attendance marked successfully!';
        });
      } else {
        setState(() {
          _currentStep = VerificationStep.failed;
          _isNetworkFailure = false;
          _errorMessage = responseBody['message'] ?? 'Verification failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Genuinely couldn't reach the server (offline, DNS failure, dropped
      // connection mid-request) — not the same as the server rejecting the
      // attempt, so the retry path resubmits the same payload instead of
      // sending the student back through face capture.
      setState(() {
        _currentStep = VerificationStep.failed;
        _isNetworkFailure = true;
        _errorMessage = "Couldn't reach the server. Check your connection and tap Retry.";
      });
    }
  }

  /// Resubmits the exact last payload — used for network-failure retries.
  Future<void> _retryLastSubmission() async {
    if (_lastQrData == null || _lastPosition == null || _lastDeviceId == null) {
      // Shouldn't happen (retry is only shown when these are set), but
      // fall back to a full restart rather than crash.
      _restartFromFaceScan();
      return;
    }
    await _submitVerification(
      qrData: _lastQrData!,
      position: _lastPosition!,
      deviceId: _lastDeviceId!,
      scannedBleUuid: _lastScannedBleUuid,
    );
  }

  /// Goes back to the QR-scan step only — reuses the already-captured face
  /// embedding + liveness result. Used for failures that aren't about the
  /// face (expired QR token, outside geofence, BLE beacon not found,
  /// duplicate submission) so the student isn't forced to redo face capture
  /// for a problem that had nothing to do with their face.
  void _rescanQrOnly() {
    setState(() {
      _currentStep = VerificationStep.qrScan;
      _isNetworkFailure = false;
      _statusMessage = "Point camera at teacher's live QR code";
    });
  }

  void _restartFromFaceScan() {
    setState(() {
      _currentStep = VerificationStep.faceScan;
      _isNetworkFailure = false;
      _statusMessage = 'Look directly into the camera';
      _extractedEmbedding = null;
      _livenessPassed = false;
      _stableGoodFrames = 0;
      _autoCaptureArmed = true;
    });
    _initFaceCamera();
  }

  bool get _isFaceRelatedFailure {
    final msg = _errorMessage.toLowerCase();
    return msg.contains('face') || msg.contains('liveness') || msg.contains('eyes');
  }

  // -------------------------------------------------------------
  // Scans nearby BLE advertisements for the teacher's session beacon.
  // Returns the matching UUID if found within the timeout, else null.
  // A null result isn't treated as a client-side failure — the backend
  // makes the final call so a flaky scan never silently blocks the
  // real check from happening server-side.
  // -------------------------------------------------------------
  Future<String?> _scanForBleBeacon(String expectedUuid, {Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final targetGuid = Guid(expectedUuid);
      final completer = Completer<String?>();
      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.advertisementData.serviceUuids.contains(targetGuid)) {
            if (!completer.isCompleted) completer.complete(expectedUuid);
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout, withServices: [targetGuid]);
      final found = await completer.future.timeout(timeout, onTimeout: () => null);

      await sub.cancel();
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      return found;
    } catch (e) {
      // BLE unsupported/permission denied on this device — return null and
      // let the backend's session.ble_uuid check produce the real error.
      return null;
    }
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
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

          // Main Viewport Area — animated so moving between steps feels
          // like one continuous flow instead of a hard screen swap.
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: _buildMainView(),
              ),
            ),
          ),

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
                      label: Text(_isProcessingFrame ? 'Processing...' : 'Capture now (or just hold still)'),
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
                  const SizedBox(height: 14),
                  if (_isNetworkFailure) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _retryLastSubmission,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _restartFromFaceScan,
                      child: const Text('Start over instead'),
                    ),
                  ] else if (_isFaceRelatedFailure) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _restartFromFaceScan,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        child: const Text('Retake Face Scan'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _rescanQrOnly,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        child: const Text('Scan QR Again'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _restartFromFaceScan,
                      child: const Text('Start over from face scan'),
                    ),
                  ],
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
        final borderColor = _stableGoodFrames > 0 ? Colors.greenAccent : Colors.amber;
        return Stack(
          alignment: Alignment.center,
          children: [
            CameraPreview(_cameraController!),
            Container(
              width: 250,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 3),
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
        return Center(
          child: Icon(
            _isNetworkFailure ? Icons.wifi_off : Icons.cancel,
            color: Colors.redAccent,
            size: 90,
          ),
        );
    }
  }
}