import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  static const _storage = FlutterSecureStorage();
  static const String _keyBaseUrl = 'app_base_url';
  
  // Default fallback for Android Emulator
  static const String defaultUrl = 'http://10.0.2.2:5000';

  /// Get the active Base URL
  static Future<String> getBaseUrl() async {
    final saved = await _storage.read(key: _keyBaseUrl);
    return saved ?? defaultUrl;
  }

  /// Set and persist a new Base URL
  static Future<void> setBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await _storage.write(key: _keyBaseUrl, value: cleanUrl);
  }

  /// Pop up dynamic configuration dialog anywhere in the app
  static Future<void> showServerConfigDialog(BuildContext context, {VoidCallback? onSaved}) async {
    final currentUrl = await getBaseUrl();
    final controller = TextEditingController(text: currentUrl);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: Colors.indigo),
            SizedBox(width: 10),
            Text('Server IP & Port', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the backend host URL for emulator or real physical device testing:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'e.g. http://192.168.0.105:5000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Quick Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Android Emulator', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = 'http://10.0.2.2:5000',
                ),
                ActionChip(
                  label: const Text('Localhost (iOS)', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = 'http://localhost:5000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await setBaseUrl(controller.text);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚡ Backend URL set to: ${controller.text.trim()}'),
                    backgroundColor: Colors.indigo,
                  ),
                );
                onSaved?.call();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }
}