import 'package:flutter/services.dart';

/// Native Barcode Scanner Service
/// Menggunakan Platform Channel untuk memanggil native camera scanner
class NativeBarcodeScanner {
  static const platform = MethodChannel('com.ymsoft.app/barcode_scanner');

  /// Scan barcode menggunakan camera native HP
  /// Returns scanned code atau null jika user cancel
  static Future<String?> scanBarcode() async {
    try {
      final String? result = await platform.invokeMethod('scanBarcode');
      return result;
    } on PlatformException catch (e) {
      print("Failed to scan barcode: ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }
}
