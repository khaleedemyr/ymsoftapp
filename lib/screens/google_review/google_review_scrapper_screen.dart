import 'package:flutter/material.dart';

import '../../services/google_review_service.dart';
import '../../widgets/app_scaffold.dart';
import 'google_review_ai_reports_screen.dart';
import 'google_review_dashboard_panel.dart';
import 'google_review_instagram_panel.dart';
import 'google_review_manual_screen.dart';
import 'google_review_maps_panel.dart';

/// Selaras menu web Google Review / Scrapper: tab Google Maps, Instagram, Dashboard + aksi Manual & riwayat AI.
class GoogleReviewScrapperScreen extends StatefulWidget {
  const GoogleReviewScrapperScreen({super.key});

  @override
  State<GoogleReviewScrapperScreen> createState() => _GoogleReviewScrapperScreenState();
}

class _GoogleReviewScrapperScreenState extends State<GoogleReviewScrapperScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GoogleReviewService _service = GoogleReviewService();

  Map<String, dynamic>? _workspace;
  bool _loadingWorkspace = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWorkspace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() => _loadingWorkspace = true);
    final r = await _service.getWorkspace();
    if (!mounted) return;
    if (r['success'] == true) {
      setState(() {
        _workspace = Map<String, dynamic>.from(r);
        _loadingWorkspace = false;
      });
    } else {
      setState(() => _loadingWorkspace = false);
    }
  }

  Map<String, dynamic>? get _dash =>
      _workspace != null && _workspace!['dashboard'] is Map ? Map<String, dynamic>.from(_workspace!['dashboard'] as Map) : null;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Google Maps & Instagram',
      showDrawer: false,
      actions: [
        IconButton(
          tooltip: 'Segarkan dashboard & metadata workspace',
          onPressed: _loadingWorkspace ? null : _loadWorkspace,
          icon: _loadingWorkspace
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.dashboard_customize_outlined),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GoogleReviewManualScreen()),
                    );
                  },
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Text('Input Manual Review'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GoogleReviewAiReportsScreen()),
                    );
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Riwayat laporan AI'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Google Maps'),
                Tab(text: 'Instagram'),
                Tab(text: 'Dashboard'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const GoogleReviewMapsPanel(),
                GoogleReviewInstagramPanel(workspace: _workspace),
                GoogleReviewDashboardPanel(
                  dashboard: _dash,
                  loading: _loadingWorkspace,
                  onRefresh: _loadWorkspace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
