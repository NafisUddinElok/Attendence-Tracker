import 'dart:convert';
import 'package:crypto/crypto.dart';

class TotpHelper {
  // Generates 8-character uppercase HMAC-SHA256 token matching backend
  static String generateRollingToken(String secret, {int offsetSeconds = 0}) {
    int timeStep = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ 15);
    var key = utf8.encode(secret);
    var bytes = utf8.encode(timeStep.toString());

    var hmac = Hmac(sha256, key);
    var digest = hmac.convert(bytes);

    return digest.toString().substring(0, 8).toUpperCase();
  }
}