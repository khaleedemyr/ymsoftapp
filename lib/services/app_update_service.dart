import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  // TODO: Ubah jika app id production berubah.
  static const String _androidId = 'com.ymsoft.erp';
  static const String _iosId = '6761749215';
  static const String _iosCountryCode = 'id';

  bool _isChecking = false;
  bool _dialogShown = false;

  /// Return true jika update tersedia dan dialog update dipaksa tampil.
  Future<bool> checkAndPromptMandatoryUpdate(BuildContext context) async {
    if (_isChecking || _dialogShown) return false;
    _isChecking = true;
    try {
      final checker = NewVersionPlus(
        androidId: _androidId,
        iOSId: _iosId,
        iOSAppStoreCountry: _iosCountryCode,
      );
      final status = await checker.getVersionStatus();
      if (status == null || !status.canUpdate) {
        return false;
      }
      if (!context.mounted) return false;

      _dialogShown = true;
      unawaited(_showMandatoryDialog(context, status));
      return true;
    } catch (_) {
      // Gagal lookup store: jangan blokir user masuk app.
      return false;
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showMandatoryDialog(
    BuildContext context,
    VersionStatus status,
  ) async {
    final currentInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Update Aplikasi Tersedia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Text(
              'Versi terbaru YMSoft App sudah tersedia.\n\n'
              'Versi saat ini: ${currentInfo.version}\n'
              'Versi terbaru: ${status.storeVersion}\n\n'
              'Silakan update aplikasi untuk melanjutkan.',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openStore(status),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Update App'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStore(VersionStatus status) async {
    final primary = status.appStoreLink.trim();
    if (primary.isNotEmpty) {
      final uri = Uri.tryParse(primary);
      if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    }

    final fallback = Platform.isIOS
        ? 'https://apps.apple.com/id/app/ymsoft-erp/id$_iosId'
        : 'https://play.google.com/store/apps/details?id=$_androidId';
    final uri = Uri.tryParse(fallback);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

