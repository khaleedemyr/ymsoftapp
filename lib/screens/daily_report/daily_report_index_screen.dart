import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/daily_report_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/daily_report/daily_report_comments_section.dart';
import 'daily_report_create_screen.dart';
import 'daily_report_show_screen.dart';
import 'daily_report_inspect_screen.dart';
import 'daily_report_post_inspection_screen.dart';
import 'daily_report_ui.dart';

class DailyReportIndexScreen extends StatefulWidget {
  const DailyReportIndexScreen({super.key});

  @override
  State<DailyReportIndexScreen> createState() => _DailyReportIndexScreenState();
}

class _DailyReportIndexScreenState extends State<DailyReportIndexScreen> {
  final DailyReportService _svc = DailyReportService();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _creator = TextEditingController();

  List<dynamic> _reports = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _permissions;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  String _status = 'all';
  String _dateFrom = '';
  String _dateTo = '';
  bool _filterExpanded = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _creator.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
      });
    } else {
      if (_page >= _lastPage || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    final res = await _svc.getReports(
      search: _search.text.trim(),
      creator: _creator.text.trim(),
      status: _status,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: reset ? 1 : _page + 1,
    );

    if (!mounted) return;

    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = res['message']?.toString() ?? 'Gagal memuat';
      });
      return;
    }

    final list = res['reports'] as List<dynamic>? ?? [];
    final pag = res['pagination'] as Map<String, dynamic>?;
    final cur = pag != null ? (pag['current_page'] as num?)?.toInt() ?? 1 : 1;
    _lastPage = pag != null ? (pag['last_page'] as num?)?.toInt() ?? 1 : 1;

    setState(() {
      if (reset) {
        _reports = List.from(list);
        _stats = res['statistics'] as Map<String, dynamic>?;
        _permissions = res['permissions'] as Map<String, dynamic>?;
      } else {
        _reports.addAll(list);
      }
      _page = cur;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  bool _canEditReport(Map<String, dynamic> report) {
    final canEdit = _permissions?['can_edit'] == true;
    final uid = _permissions?['current_user_id'];
    final creatorId = report['user_id'];
    return canEdit || (uid != null && creatorId != null && '$uid' == '$creatorId');
  }

  int _reportRating(Map<String, dynamic> report) {
    final areas = report['report_areas'] as List<dynamic>? ?? [];
    if (areas.isEmpty) return 0;
    final good = areas.where((a) => (a as Map)['status'] == 'G').length;
    final ng = areas.where((a) => (a as Map)['status'] == 'NG').length;
    final inspected = good + ng;
    if (inspected == 0) return 0;
    return ((good / inspected) * 100).round();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final s = DateFormat('yyyy-MM-dd').format(picked);
      if (isFrom) {
        _dateFrom = s;
      } else {
        _dateTo = s;
      }
    });
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final id = (report['id'] as num?)?.toInt();
    if (id == null) return;
    final outlet = report['outlet'] is Map ? (report['outlet'] as Map)['nama_outlet'] : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Report?'),
        content: Text('Yakin hapus daily report untuk $outlet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _svc.deleteReport(id);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Terhapus'), behavior: SnackBarBehavior.floating));
      _load(reset: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _openSummaryRating() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    var startDate = DateFormat('yyyy-MM-dd').format(start);
    var endDate = DateFormat('yyyy-MM-dd').format(now);
    String? region;
    List<dynamic> regions = [];
    List<dynamic> summaryData = [];
    bool loading = false;
    final expanded = <int>{};

    final regionsRes = await _svc.getRegions();
    if (regionsRes['success'] == true) {
      regions = regionsRes['data'] as List<dynamic>? ?? [];
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DrColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> loadSummary() async {
              setModal(() => loading = true);
              final res = await _svc.getSummaryRating(startDate: startDate, endDate: endDate, region: region);
              setModal(() {
                loading = false;
                summaryData = res['success'] == true ? (res['data'] as List<dynamic>? ?? []) : [];
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scroll) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: DrColors.border, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    const Text('Summary Rating', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DrColors.textPrimary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () async {
                          final p = await showDatePicker(context: ctx, initialDate: DateTime.parse(startDate), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (p != null) setModal(() => startDate = DateFormat('yyyy-MM-dd').format(p));
                        }, child: Text('Dari: $startDate', style: const TextStyle(fontSize: 12)))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: () async {
                          final p = await showDatePicker(context: ctx, initialDate: DateTime.parse(endDate), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (p != null) setModal(() => endDate = DateFormat('yyyy-MM-dd').format(p));
                        }, child: Text('Sampai: $endDate', style: const TextStyle(fontSize: 12)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: region,
                      decoration: drInputDecoration('Region'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Semua Region')),
                        ...regions.map((r) {
                          final m = r as Map<String, dynamic>;
                          return DropdownMenuItem(value: '${m['id']}', child: Text(m['name']?.toString() ?? ''));
                        }),
                      ],
                      onChanged: (v) => setModal(() => region = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: DrColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: loading ? null : loadSummary,
                        icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.analytics_outlined),
                        label: const Text('Load Data'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: summaryData.length,
                        itemBuilder: (_, i) {
                          final item = summaryData[i] as Map<String, dynamic>;
                          final outletId = (item['id'] as num?)?.toInt() ?? 0;
                          return DrSectionCard(
                            padding: EdgeInsets.zero,
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                              title: Text(item['nama_outlet']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Rating ${item['average_rating']}% · ${item['completed_reports']} selesai', style: const TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                              onExpansionChanged: (v) => setModal(() {
                                if (v) expanded.add(outletId); else expanded.remove(outletId);
                              }),
                              children: [
                                FutureBuilder<Map<String, dynamic>>(
                                  future: _svc.getDepartmentRatings(outletId: outletId, startDate: startDate, endDate: endDate, region: region),
                                  builder: (c, snap) {
                                    if (!snap.hasData || snap.data?['success'] != true) {
                                      return const Padding(padding: EdgeInsets.all(16), child: Text('Memuat departemen...'));
                                    }
                                    final deps = snap.data!['data'] as List<dynamic>? ?? [];
                                    return Column(
                                      children: deps.map((d) {
                                        final dm = d as Map<String, dynamic>;
                                        return ListTile(
                                          dense: true,
                                          title: Text(dm['nama_departemen']?.toString() ?? ''),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: DrColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                                            child: Text('${dm['average_rating']}%', style: const TextStyle(fontWeight: FontWeight.w700, color: DrColors.primary)),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Daily Report',
      actions: [
        IconButton(
          onPressed: _openSummaryRating,
          icon: const Icon(Icons.insights_rounded),
          tooltip: 'Summary Rating',
        ),
      ],
      body: Container(
        color: DrColors.surface,
        child: RefreshIndicator(
          color: DrColors.primary,
          onRefresh: () => _load(reset: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(child: Center(child: AppLoadingIndicator()))
              else if (_error != null)
                SliverFillRemaining(child: _buildEmptyState(Icons.error_outline_rounded, _error!, action: FilledButton(onPressed: () => _load(reset: true), child: const Text('Coba lagi'))))
              else if (_reports.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(Icons.assignment_outlined, 'Belum ada daily report', subtitle: 'Tap + untuk buat laporan baru'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _reports.length) {
                          if (_page < _lastPage) {
                            _load();
                            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: DrColors.primary)));
                          }
                          return const SizedBox(height: 16);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _reportCard(_reports[index] as Map<String, dynamic>),
                        );
                      },
                      childCount: _reports.length + 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DrColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReportCreateScreen()));
          _load(reset: true);
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Buat Report', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats != null) ...[
            Row(
              children: [
                DrStatCard(label: 'Total', value: '${_stats!['total']}', icon: Icons.folder_copy_rounded, gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                const SizedBox(width: 10),
                DrStatCard(label: 'Draft', value: '${_stats!['draft']}', icon: Icons.edit_note_rounded, gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)]),
                const SizedBox(width: 10),
                DrStatCard(label: 'Selesai', value: '${_stats!['completed']}', icon: Icons.check_circle_outline_rounded, gradient: const [Color(0xFF10B981), Color(0xFF059669)]),
              ],
            ),
            const SizedBox(height: 16),
          ],
          DrSearchBar(
            controller: _search,
            onSearch: () => _load(reset: true),
            onFilterTap: () => setState(() => _filterExpanded = !_filterExpanded),
            filterActive: _filterExpanded || _status != 'all' || _dateFrom.isNotEmpty || _dateTo.isNotEmpty || _creator.text.isNotEmpty,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _filterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DrSectionCard(
                child: Column(
                  children: [
                    TextField(controller: _creator, decoration: drInputDecoration('Nama creator', icon: Icons.person_outline_rounded)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: drInputDecoration('Status', icon: Icons.flag_outlined),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Semua status')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'all'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(true),
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(_dateFrom.isEmpty ? 'Dari' : _dateFrom, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(false),
                            icon: const Icon(Icons.event_rounded, size: 16),
                            label: Text(_dateTo.isEmpty ? 'Sampai' : _dateTo, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: DrColors.primary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => _load(reset: true),
                            child: const Text('Terapkan Filter'),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _creator.clear();
                              _status = 'all';
                              _dateFrom = '';
                              _dateTo = '';
                            });
                            _load(reset: true);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, {String? subtitle, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: DrColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: DrColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: DrColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: DrColors.textSecondary)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final id = (report['id'] as num).toInt();
    final outlet = report['outlet'] is Map ? (report['outlet'] as Map)['nama_outlet']?.toString() : '-';
    final dept = report['department'] is Map ? (report['department'] as Map)['nama_departemen']?.toString() : '-';
    final userMap = report['user'] is Map ? Map<String, dynamic>.from(report['user'] as Map) : null;
    final userName = userMap?['nama_lengkap']?.toString() ?? '-';
    final jabatan = userMap?['jabatan'] is Map ? (userMap!['jabatan'] as Map)['nama_jabatan']?.toString() : null;
    final status = report['status']?.toString() ?? '';
    final time = report['inspection_time']?.toString() ?? '';
    final isLunch = time == 'lunch';
    final rating = _reportRating(report);
    final created = report['created_at']?.toString() ?? '';
    String createdLabel = created;
    try {
      createdLabel = DateFormat('dd MMM yyyy · HH:mm', 'id_ID').format(DateTime.parse(created));
    } catch (_) {}

    final isDone = status == 'completed';

    return Material(
      color: Colors.transparent,
      child: DrSectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportShowScreen(reportId: id)));
                _load(reset: true);
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DrUserAvatar(user: userMap, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(outlet ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DrColors.textPrimary, height: 1.2)),
                            const SizedBox(height: 4),
                            Text(userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DrColors.textPrimary)),
                            if (jabatan != null && jabatan.isNotEmpty)
                              Text(jabatan, style: const TextStyle(fontSize: 11, color: DrColors.textSecondary)),
                          ],
                        ),
                      ),
                      _statusPill(isDone),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      DrChip(label: dept ?? '-', color: DrColors.primary, icon: Icons.business_rounded),
                      DrChip(
                        label: isLunch ? 'Lunch' : 'Dinner',
                        color: isLunch ? const Color(0xFFEA580C) : const Color(0xFF7C3AED),
                        icon: isLunch ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      ),
                      if (rating > 0)
                        DrChip(label: '$rating%', color: DrColors.success, icon: Icons.star_rounded),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: DrColors.textSecondary.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(createdLabel, style: const TextStyle(fontSize: 12, color: DrColors.textSecondary)),
                      ),
                    ],
                  ),
                  if (status == 'draft' && _canEditReport(report)) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: DrColors.border),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _actionBtn(
                          icon: Icons.fact_check_outlined,
                          label: 'Inspect',
                          color: DrColors.primary,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportInspectScreen(reportId: id)));
                            _load(reset: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        _actionBtn(
                          icon: Icons.assignment_outlined,
                          label: 'Post',
                          color: const Color(0xFF0EA5E9),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportPostInspectionScreen(reportId: id)));
                            _load(reset: true);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteReport(report),
                          icon: const Icon(Icons.delete_outline_rounded, color: DrColors.danger, size: 22),
                          tooltip: 'Hapus',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            DailyReportCommentsSection(
              reportId: id,
              initialComments: report['comments'] as List<dynamic>? ?? [],
              currentUserId: (_permissions?['current_user_id'] as num?)?.toInt(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: isDone ? DrColors.success : DrColors.warning, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isDone ? 'Selesai' : 'Draft',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDone ? DrColors.success : DrColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
