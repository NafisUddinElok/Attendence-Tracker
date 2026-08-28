import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'UNKNOWN_IOS_DEVICE';
      }
      return 'UNKNOWN_PLATFORM_DEVICE';
    } catch (e) {
      return 'FALLBACK_DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}