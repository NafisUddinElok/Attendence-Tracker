import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// The TFLite model (mobilefacenet) emits a 192-dimensional face vector.
/// The Phase 6 backend contract (FACE_EMBED_DIM) is 128. We truncate the
/// output to the first 128 components and re-L2-normalise so cosine
/// similarity downstream still works as expected.
const int kTfliteOutputDim = 192;
const int kContractEmbeddingDim = 128;

class FaceEmbeddingService {
  Interpreter? _interpreter;
  bool _isInitializing = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  Future<void> init() async {
    if (_interpreter != null) return;
    if (_isInitializing) return;

    _isInitializing = true;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      debugPrint('? TFLite model loaded successfully');
    } catch (e) {
      debugPrint('? Error loading TFLite model: ');
      _interpreter = null;
    } finally {
      _isInitializing = false;
    }
  }

  /// Detect exactly one face from an image file. Returns null if zero or
  /// multiple faces are found (proxy-attack guard).
  Future<Face?> detectSingleFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.length == 1) {
      return faces.first;
    }
    return null;
  }

  /// Truncate a TFLite embedding to the backend's expected dimension and
  /// re-normalise to unit length.
  List<double> projectToContractDim(List<double> raw) {
    final dim = math.min(raw.length, kContractEmbeddingDim);
    final out = List<double>.filled(kContractEmbeddingDim, 0.0);
    for (int i = 0; i < dim; i++) {
      out[i] = raw[i];
    }
    var norm = 0.0;
    for (int i = 0; i < kContractEmbeddingDim; i++) {
      norm += out[i] * out[i];
    }
    norm = math.sqrt(norm);
    if (norm == 0) return out; // caller should reject
    for (int i = 0; i < kContractEmbeddingDim; i++) {
      out[i] /= norm;
    }
    return out;
  }

  /// Crop face, resize to 112x112, normalise [-1, 1], and extract the
  /// 192D TFLite vector. Returns the 128-D contracted form expected by
  /// the backend.
  Future<List<double>?> extractFaceEmbedding(String imagePath, Face face) async {
    if (_interpreter == null) {
      await init();
    }
    if (_interpreter == null) {
      debugPrint('? Interpreter is null, cannot extract embedding');
      return null;
    }

    final bytes = await File(imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    final box = face.boundingBox;
    int x = box.left.toInt().clamp(0, originalImage.width - 1);
    int y = box.top.toInt().clamp(0, originalImage.height - 1);
    int w = box.width.toInt().clamp(1, originalImage.width - x);
    int h = box.height.toInt().clamp(1, originalImage.height - y);

    img.Image croppedFace = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);
    img.Image resizedFace = img.copyResize(croppedFace, width: 112, height: 112);

    var input = List.generate(
      1,
      (i) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = resizedFace.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128.0,
              (pixel.g - 127.5) / 128.0,
              (pixel.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );

    var output = List.filled(1 * kTfliteOutputDim, 0.0).reshape([1, kTfliteOutputDim]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('? Error running interpreter: ');
      return null;
    }

    final raw = List<double>.from(output[0]);
    return projectToContractDim(raw);
  }

  /// Phase 6 helper: capture multiple photos in quick succession, run them
  /// through the model, and return the canonical 128-D vectors.
  /// Used by face enrolment to feed the server an embeddings[] array.
  Future<List<List<double>>?> extractMultipleEmbeddings(
    List<String> imagePaths,
    List<Face> faces,
  ) async {
    if (imagePaths.length != faces.length) {
      throw ArgumentError(
        'imagePaths.length () != faces.length ()',
      );
    }
    final out = <List<double>>[];
    for (var i = 0; i < imagePaths.length; i++) {
      final v = await extractFaceEmbedding(imagePaths[i], faces[i]);
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
    _interpreter = null;
  }
}

