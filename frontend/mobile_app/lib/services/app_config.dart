import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  static const _storage = FlutterSecureStorage();
  static const String _keyBaseUrl = 'app_base_url';

  // Once the backend is deployed (see backend/render.yaml), replace this
  // with the real https:// URL Render/Railway gives you, e.g.
  // 'https://attendance-tracker-backend.onrender.com'. That single change
  // is what removes the "everyone must be on my WiFi / re-enter my laptop's
  // IP every class" problem — after that, this dialog becomes an escape
  // hatch for local development rather than something students ever touch.
  static const String productionUrl = 'https://attendance-tracker-backend-idqe.onrender.com';

  // Fallback for Android Emulator during local development.
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
        // ✅ FIX: With 3 preset chips now (Production, Emulator, Localhost),
        // the Wrap can grow to 2 lines — combined with the keyboard opening
        // when the TextField is focused, the Column's natural height could
        // exceed the available dialog space. SingleChildScrollView lets the
        // content scroll internally instead of overflowing.
        content: SingleChildScrollView(
          child: Column(
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
                runSpacing: 6, // ✅ breathing room when chips wrap to a 2nd line
                children: [
                  ActionChip(
                    label: const Text('Production (Cloud)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                    onPressed: () => controller.text = productionUrl,
                  ),
                  ActionChip(
                    label: const Text('Android Emulator (local dev)', style: TextStyle(fontSize: 11)),
                    onPressed: () => controller.text = 'http://10.0.2.2:5000',
                  ),
                  ActionChip(
                    label: const Text('Localhost (local dev)', style: TextStyle(fontSize: 11)),
                    onPressed: () => controller.text = 'http://localhost:5000',
                  ),
                ],
              ),
            ],
          ),
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