import 'package:flutter/material.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_loading_indicator.dart';

class AssetInventoryAdjustmentDetailScreen extends StatefulWidget {
  final int adjustmentId;

  const AssetInventoryAdjustmentDetailScreen({
    super.key,
    required this.adjustmentId,
  });

  @override
  State<AssetInventoryAdjustmentDetailScreen> createState() => _AssetInventoryAdjustmentDetailScreenState();
}

class _AssetInventoryAdjustmentDetailScreenState extends State<AssetInventoryAdjustmentDetailScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading asset adjustment detail: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Adjustment Detail'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : const Center(
              child: Text(
                'Asset Inventory Adjustment Detail\n(Coming soon)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
    );
  }
}
