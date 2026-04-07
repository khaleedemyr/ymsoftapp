package com.ymsoft.erp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ymsoft.app/barcode_scanner"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanBarcode") {
                pendingResult = result
                startBarcodeScanner()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startBarcodeScanner() {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .enableAutoZoom()
            .build()

        val scanner = GmsBarcodeScanning.getClient(this, options)
        
        scanner.startScan()
            .addOnSuccessListener { barcode ->
                // Scan berhasil
                val rawValue = barcode.rawValue
                pendingResult?.success(rawValue)
                pendingResult = null
            }
            .addOnCanceledListener {
                // User cancel
                pendingResult?.success(null)
                pendingResult = null
            }
            .addOnFailureListener { e ->
                // Error
                pendingResult?.error("SCAN_ERROR", e.message, null)
                pendingResult = null
            }
    }
}
