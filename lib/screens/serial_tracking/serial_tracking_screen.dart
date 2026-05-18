import 'package:flutter/material.dart';
import '../../services/serial_tracking_service.dart';
import '../../widgets/app_scaffold.dart';
import 'serial_tracking_document_tab.dart';
import 'serial_tracking_pending_tab.dart';
import 'serial_tracking_serial_tab.dart';

/// Tracking Nomor Seri — selaras web (3 tab: Per Dokumen, Per Nomor Seri, Belum GR Outlet).
class SerialTrackingScreen extends StatefulWidget {
  const SerialTrackingScreen({super.key});

  @override
  State<SerialTrackingScreen> createState() => _SerialTrackingScreenState();
}

class _SerialTrackingScreenState extends State<SerialTrackingScreen> with SingleTickerProviderStateMixin {
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _amber = Color(0xFFD97706);

  final SerialTrackingService _service = SerialTrackingService();
  late final TabController _tabController;

  bool _metaLoaded = false;
  bool _isHQ = false;
  List<Map<String, dynamic>> _sourceTypes = [];
  List<Map<String, dynamic>> _outlets = [];

  int _pendingBadge = 0;
  final GlobalKey<SerialTrackingSerialTabState> _serialTabKey = GlobalKey();
  final GlobalKey<SerialTrackingPendingTabState> _pendingTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        if (_tabController.index == 2) {
          _pendingTabKey.currentState?.ensureLoaded();
        }
      }
    });
    _loadMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final res = await _service.getMeta();
    if (!mounted) return;
    if (res != null) {
      setState(() {
        _metaLoaded = true;
        _isHQ = res['is_hq'] == true;
        _sourceTypes = _parseList(res['source_types']);
        _outlets = _parseList(res['outlets']);
      });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _trackSerial(String serialNumber) async {
    final sn = serialNumber.trim();
    if (sn.length < 2) return;
    _tabController.animateTo(1);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    // Sama web: isi nomor seri + langsung lookup
    await _serialTabKey.currentState?.applyAndLookup(sn);
  }

  Color get _tabAccent => _tabController.index == 2 ? _amber : _indigo;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tracking Nomor Seri',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Lacak serial berdasarkan dokumen sumber atau nomor seri langsung',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _tabAccent,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: _tabAccent,
              tabs: [
                const Tab(text: 'Per Dokumen'),
                const Tab(text: 'Per Nomor Seri'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Belum GR Outlet'),
                      if (_pendingBadge > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_pendingBadge',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _metaLoaded
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      SerialTrackingDocumentTab(
                        service: _service,
                        sourceTypes: _sourceTypes,
                        onTrackSerial: _trackSerial,
                      ),
                      SerialTrackingSerialTab(
                        key: _serialTabKey,
                        service: _service,
                      ),
                      SerialTrackingPendingTab(
                        key: _pendingTabKey,
                        service: _service,
                        isHQ: _isHQ,
                        outlets: _outlets,
                        onTrackSerial: _trackSerial,
                        onSummaryLoaded: (total) => setState(() => _pendingBadge = total),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator(color: _indigo)),
          ),
        ],
      ),
    );
  }
}
