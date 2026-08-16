import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Phase 6 device identity: derive a stable, non-PII device id from the
/// Android androidId / iOS identifierForVendor by SHA-256 hashing the
/// raw vendor-supplied string and slicing to a 32-hex token.
///
/// Why hash?
///   * androidId and identifierForVendor are reversible identifiers
///     that can be used to track a user across apps.
///   * The server only needs a stable opaque string to bind a face to a
///     device. Hashing lets us rotate the underlying vendor id without
///     breaking the binding contract, and prevents leaks from device-info
///     service logs from being personally identifying.
///
/// The id is *device-scoped, not app-scoped*; resets on factory reset.
class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Resolve the underlying vendor id. Throws on unknown platforms
  /// rather than fabricating a fallback token - the anti-proxy contract
  /// requires a real, repeatable device identifier.
  static Future<String> _rawDeviceId() async {
    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await _deviceInfo.androidInfo;
      return info.id;
    }
    if (Platform.isIOS) {
      final IosDeviceInfo info = await _deviceInfo.iosInfo;
      final id = info.identifierForVendor;
      if (id == null || id.isEmpty) {
        throw const DeviceIdUnavailable(
          'iOS identifierForVendor was null/empty.',
        );
      }
      return id;
    }
    throw const DeviceIdUnavailable(
      'Device identity is only available on Android and iOS.',
    );
  }

  /// Returns a 32-hex-character SHA-256 of the vendor device id.
  /// Stable for the lifetime of an Android install (until factory reset)
  /// or an iOS app install (until app uninstall).
  static Future<String> getDeviceId() async {
    final raw = await _rawDeviceId();
    final digest = sha256.convert(utf8.encode(raw));
    // 32 hex chars (128 bits) is more than enough collision resistance
    // for the one-student-one-device constraint.
    return digest.toString().substring(0, 32);
  }
}

/// Raised when the platform can't surface a stable device identity.
/// Callers should fail-closed: do not allow attendance if we can't
/// prove which device the student is on.
class DeviceIdUnavailable implements Exception {
  final String message;
  const DeviceIdUnavailable(this.message);

  @override
  String toString() => 'DeviceIdUnavailable: $message';
}