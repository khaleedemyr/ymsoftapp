import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';

class AssetInventoryTransferDetailScreen extends StatefulWidget {
  final int transferId;

  const AssetInventoryTransferDetailScreen({
    super.key,
    required this.transferId,
  });

  @override
  State<AssetInventoryTransferDetailScreen> createState() => _AssetInventoryTransferDetailScreenState();
}

class _AssetInventoryTransferDetailScreenState extends State<AssetInventoryTransferDetailScreen> {
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
      print('Error loading asset transfer detail: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Transfer Detail'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : const Center(
              child: Text(
                'Asset Inventory Transfer Detail\n(Coming soon)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
    );
  }
}
