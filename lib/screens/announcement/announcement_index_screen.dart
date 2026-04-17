import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/announcement_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'announcement_detail_screen.dart';
import 'announcement_form_screen.dart';

class AnnouncementIndexScreen extends StatefulWidget {
  const AnnouncementIndexScreen({super.key});

  @override
  State<AnnouncementIndexScreen> createState() => _AnnouncementIndexScreenState();
}

class _AnnouncementIndexScreenState extends State<AnnouncementIndexScreen> {
  final AnnouncementService _service = AnnouncementService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 1;
  int _lastPage = 1;
  final List<Map<String, dynamic>> _items = [];

  String _search = '';
  String? _startDate;
  String? _endDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAnnouncements(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoadingMore && !_isLoading && _hasMore) {
        _loadAnnouncements(refresh: false);
      }
    }
  }

  Future<void> _loadAnnouncements({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final targetPage = refresh ? 1 : (_page + 1);
    final result = await _service.getAnnouncements(
      search: _search.isEmpty ? null : _search,
      startDate: _startDate,
      endDate: _endDate,
      page: targetPage,
      perPage: 10,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = result['message']?.toString() ?? 'Gagal memuat announcement';
      });
      return;
    }

    final announcements = result['announcements'] is Map
        ? Map<String, dynamic>.from(result['announcements'] as Map)
        : <String, dynamic>{};
    final data = ((announcements['data'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final page = _toInt(announcements['current_page'], defaultValue: targetPage);
    final lastPage = _toInt(announcements['last_page'], defaultValue: 1);

    setState(() {
      if (refresh) {
        _items
          ..clear()
          ..addAll(data);
      } else {
        _items.addAll(data);
      }
      _page = page;
      _lastPage = lastPage <= 0 ? 1 : lastPage;
      _hasMore = _page < _lastPage;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  void _applyFilter() {
    setState(() {
      _search = _searchController.text.trim();
      _startDate = _startDateController.text.trim().isEmpty ? null : _startDateController.text.trim();
      _endDate = _endDateController.text.trim().isEmpty ? null : _endDateController.text.trim();
    });
    _loadAnnouncements(refresh: true);
  }

  void _resetFilter() {
    setState(() {
      _searchController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _search = '';
      _startDate = null;
      _endDate = null;
    });
    _loadAnnouncements(refresh: true);
  }

  Future<void> _openDetail(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcementId: id)),
    );
    if (!mounted) return;
    _loadAnnouncements(refresh: true);
  }

  Future<void> _openForm({int? id}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementFormScreen(announcementId: id)),
    );
    if (changed == true && mounted) {
      _loadAnnouncements(refresh: true);
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Announcement?'),
        content: const Text('Yakin ingin menghapus pengumuman ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await _service.deleteAnnouncement(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil dihapus' : 'Gagal dihapus')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      _loadAnnouncements(refresh: true);
    }
  }

  Future<void> _publishAnnouncement(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Announcement?'),
        content: const Text('Yakin publish pengumuman ini sekarang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true) return;

    final result = await _service.publishAnnouncement(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil dipublish' : 'Gagal publish')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      _loadAnnouncements(refresh: true);
    }
  }

  Color _statusBg(String status) => status == 'Publish' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
  Color _statusFg(String status) => status == 'Publish' ? const Color(0xFF166534) : const Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Announcement',
      showDrawer: false,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Announcement',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Buat'),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cari judul announcement',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _applyFilter(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startDateController,
                          readOnly: true,
                          onTap: () => _pickDate(_startDateController),
                          decoration: const InputDecoration(
                            labelText: 'Tanggal awal',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _endDateController,
                          readOnly: true,
                          onTap: () => _pickDate(_endDateController),
                          decoration: const InputDecoration(
                            labelText: 'Tanggal akhir',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetFilter,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Cari'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () => _loadAnnouncements(refresh: true),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadAnnouncements(refresh: true),
                        child: _items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('Tidak ada data Announcement')),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  }
                                  final item = _items[index];
                                  final id = _toInt(item['id']);
                                  final status = item['status']?.toString() ?? '-';
                                  final targets = ((item['targets'] as List?) ?? const [])
                                      .map((e) => Map<String, dynamic>.from(e as Map))
                                      .toList();
                                  final files = ((item['files'] as List?) ?? const []);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['title']?.toString() ?? '-',
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _statusBg(status),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: _statusFg(status),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['created_at_formatted']?.toString() ?? item['created_at']?.toString() ?? '-',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: targets.map((target) {
                                              final label =
                                                  '${target['target_type']}: ${target['target_name'] ?? target['target_id']}';
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF1E40AF),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          if (files.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text('Lampiran: ${files.length} file', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                          ],
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => _openDetail(id),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF1E40AF),
                                                ),
                                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                                label: const Text('Detail'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => _openForm(id: id),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF92400E),
                                                ),
                                                icon: const Icon(Icons.edit_outlined, size: 18),
                                                label: const Text('Edit'),
                                              ),
                                              if (status == 'DRAFT')
                                                FilledButton.icon(
                                                  onPressed: () => _publishAnnouncement(id),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: const Color(0xFF16A34A),
                                                  ),
                                                  icon: const Icon(Icons.check_rounded, size: 18),
                                                  label: const Text('Publish'),
                                                ),
                                              FilledButton.icon(
                                                onPressed: () => _deleteAnnouncement(id),
                                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                                label: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

