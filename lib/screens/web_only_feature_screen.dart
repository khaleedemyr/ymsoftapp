import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_scaffold.dart';
import '../services/auth_service.dart';

class WebOnlyFeatureScreen extends StatelessWidget {
  final String? featureName;
  /// Optional path to open in browser (e.g. '/outlet-transfer'). Uses AuthService.baseUrl + webPath.
  final String? webPath;

  const WebOnlyFeatureScreen({super.key, this.featureName, this.webPath});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: featureName ?? 'Fitur Web',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.laptop_chromebook,
                size: 120,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 32),
              Text(
                'Fitur Ini Hanya Tersedia di Web',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                featureName != null
                    ? 'Fitur "$featureName" saat ini hanya dapat diakses melalui website YMSoft ERP.'
                    : 'Fitur ini saat ini hanya dapat diakses melalui website YMSoft ERP.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan akses melalui browser untuk menggunakan fitur ini.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final String url = webPath != null && webPath!.isNotEmpty
                        ? '${AuthService.baseUrl}$webPath'
                        : 'https://ymsofterp.com';
                    final uri = Uri.parse(url);
                    
                    // Try to launch URL - use platformDefault first as it's more reliable
                    try {
                      final launched = await launchUrl(
                        uri,
                        mode: LaunchMode.platformDefault,
                      );
                      
                      if (!launched && context.mounted) {
                        // If platformDefault fails, try externalApplication
                        try {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (e) {
                          print('External application launch failed: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tidak dapat membuka browser. Silakan buka https://ymsofterp.com secara manual.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      print('Error launching URL: $e');
                      // Try externalApplication as fallback
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e2) {
                        print('Fallback launch also failed: $e2');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Tidak dapat membuka browser. Silakan buka https://ymsofterp.com secara manual.'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    print('Unexpected error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terjadi kesalahan. Silakan buka https://ymsofterp.com secara manual.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Buka di Browser'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

