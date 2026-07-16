import 'package:flutter/material.dart';
import '../../models/sop_development_completion_models.dart';
import '../../services/sop_development_completion_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'sop_development_completion_form_screen.dart';
import 'sop_development_completion_show_screen.dart';
import 'sop_development_completion_submit_screen.dart';
import 'sop_development_completion_ui.dart';

class SopDevelopmentCompletionIndexScreen extends StatefulWidget {
  const SopDevelopmentCompletionIndexScreen({super.key});

  @override
  State<SopDevelopmentCompletionIndexScreen> createState() => _SopDevelopmentCompletionIndexScreenState();
}

class _SopDevelopmentCompletionIndexScreenState extends State<SopDevelopmentCompletionIndexScreen> {
  final _service = SopDevelopmentCompletionService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  String _filterStatus = 'all';
  List<SopListItem> _records = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _page = 1;
      if (!_loading) setState(() => _loading = true);
    } else {
      if (_loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
      _page += 1;
    }

    final res = await _service.fetchIndex(
      page: _page,
      search: _searchCtrl.text.trim(),
      status: _filterStatus,
    );

    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      return;
    }

    final pagination = res['pagination'] as Map? ?? {};
    final rows = (res['records'] as List? ?? [])
        .map((e) => SopListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() {
      if (reset) {
        _records = rows;
      } else {
        _records = [..._records, ...rows];
      }
      _lastPage = pagination['last_page'] as int? ?? 1;
      _loading = false;
      _loadingMore = false;
    });
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SopDevelopmentCompletionUi.statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        SopDevelopmentCompletionUi.statusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SopDevelopmentCompletionUi.statusColor(status)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'SOP Development',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SopDevelopmentCompletionFormScreen()));
          if (mounted) _load(reset: true);
        },
        backgroundColor: SopDevelopmentCompletionUi.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 && !_loading && !_loadingMore) {
              _load(reset: false);
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: SopDevelopmentCompletionUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Kelola pengembangan SOP, upload dokumen, dan ajukan approval',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari judul atau deskripsi...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _load(reset: true),
                  ),
                ),
                onSubmitted: (_) => _load(reset: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Semua')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'pending', child: Text('Menunggu Approval')),
                  DropdownMenuItem(value: 'approved', child: Text('Selesai')),
                  DropdownMenuItem(value: 'rejected', child: Text('Ditolak')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _filterStatus = v);
                  _load(reset: true);
                },
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: AppLoadingIndicator()),
                )
              else if (_records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Belum ada data SOP development.', style: TextStyle(color: SopDevelopmentCompletionUi.textMuted))),
                )
              else
                ..._records.map((record) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: SopDevelopmentCompletionUi.cardDecoration,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (record.description != null && record.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(record.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'Due: ${SopDevelopmentCompletionUi.formatDate(record.dueDate)}${record.isOverdue ? ' (Overdue)' : ''}',
                            style: TextStyle(fontSize: 12, color: record.isOverdue ? Colors.red : SopDevelopmentCompletionUi.textMuted),
                          ),
                          const SizedBox(height: 8),
                          _statusChip(record.status),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'detail') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SopDevelopmentCompletionShowScreen(recordId: record.id)),
                            );
                            if (mounted) _load(reset: true);
                          } else if (action == 'submit') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SopDevelopmentCompletionSubmitScreen(recordId: record.id, title: record.title)),
                            );
                            if (mounted) _load(reset: true);
                          } else if (action == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Hapus SOP?'),
                                content: Text('Yakin ingin menghapus "${record.title}"?'),
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
                            if (ok == true) {
                              final res = await _service.delete(record.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Selesai')));
                              _load(reset: true);
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'detail', child: Text('Detail')),
                          if (record.canSubmit)
                            const PopupMenuItem(value: 'submit', child: Text('Submit / Upload Ulang')),
                          if (record.canDelete)
                            const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SopDevelopmentCompletionShowScreen(recordId: record.id)),
                        ).then((_) => _load(reset: true));
                      },
                    ),
                  );
                }),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: AppLoadingIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
