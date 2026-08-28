import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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
    // already loaded, skip
    if (_interpreter != null) return;
    // prevent duplicate parallel init calls
    if (_isInitializing) return;

    _isInitializing = true;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      debugPrint('✅ TFLite model loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading TFLite model: $e');
      _interpreter = null; // explicit, so caller can check
    } finally {
      _isInitializing = false;
    }
  }

  // Detect single face from image file
  Future<Face?> detectSingleFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.length == 1) {
      return faces.first;
    }
    return null;
  }

  // Crop face, resize to 112x112, normalize [-1, 1], and extract 192D vector
  Future<List<double>?> extractFaceEmbedding(String imagePath, Face face) async {
    // make sure model is loaded before using it
    if (_interpreter == null) {
      await init();
    }

    // model still failed to load -> bail out gracefully instead of crashing
    if (_interpreter == null) {
      debugPrint('❌ Interpreter is null, cannot extract embedding');
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

    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('❌ Error running interpreter: $e');
      return null;
    }

    return List<double>.from(output[0]);
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
    _interpreter = null;
  }
}