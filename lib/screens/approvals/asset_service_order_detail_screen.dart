import 'package:flutter/material.dart';
import '../../services/approval_service.dart';
import '../../widgets/app_loading_indicator.dart';

class AssetServiceOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const AssetServiceOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<AssetServiceOrderDetailScreen> createState() => _AssetServiceOrderDetailScreenState();
}

class _AssetServiceOrderDetailScreenState extends State<AssetServiceOrderDetailScreen> {
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
      print('Error loading asset service order detail: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Service Order Detail'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : const Center(
              child: Text(
                'Asset Service Order Detail\n(Coming soon)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
    );
  }
}
