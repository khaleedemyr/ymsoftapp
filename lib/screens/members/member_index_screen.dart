import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/member_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';

class MemberIndexScreen extends StatefulWidget {
  const MemberIndexScreen({super.key});

  @override
  State<MemberIndexScreen> createState() => _MemberIndexScreenState();
}

class _MemberIndexScreenState extends State<MemberIndexScreen> {
  final MemberService _service = MemberService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic> _stats = const {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _lastPage = 1;
  String _statusFilter = '';
  String _pointBalanceFilter = '';
  String? _error;
  int _unverifiedCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadData(refresh: false);
      }
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _formatInt(dynamic value) {
    return NumberFormat('#,##0', 'id_ID').format(_toInt(value));
  }

  Future<void> _loadData({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _lastPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final targetPage = refresh ? 1 : _page + 1;
    final result = await _service.getMembers(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _statusFilter.isEmpty ? null : _statusFilter,
      pointBalance: _pointBalanceFilter.isEmpty ? null : _pointBalanceFilter,
      page: targetPage,
      perPage: 15,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat data';
        if (refresh) _members = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final membersObj = result['members'];
    final data = membersObj is Map ? membersObj['data'] : null;
    final list = data is List
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final lastPage = membersObj is Map ? _toInt(membersObj['last_page'], fallback: 1) : 1;

    setState(() {
      _stats = result['stats'] is Map ? Map<String, dynamic>.from(result['stats'] as Map) : {};
      _unverifiedCount = _toInt(result['unverifiedCount']);
      if (refresh) {
        _members = list;
      } else {
        _members.addAll(list);
      }
      _page = targetPage;
      _lastPage = lastPage;
      _hasMore = _page < _lastPage;
      _isLoading = false;
      _isLoadingMore = false;
      _error = null;
    });
  }

  Future<void> _toggleStatus(Map<String, dynamic> member) async {
    final id = _toInt(member['id']);
    if (id <= 0) return;
    final isActive = member['is_active'] == true || member['status_aktif']?.toString() == '1';
    final actionLabel = isActive ? 'nonaktifkan' : 'aktifkan';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${actionLabel[0].toUpperCase()}${actionLabel.substring(1)} member?'),
        content: Text('Yakin ingin $actionLabel ${member['nama_lengkap'] ?? member['name'] ?? '-'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final result = await _service.toggleStatus(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      _loadData(refresh: true);
    }
  }

  Future<void> _verifyAllUnverified() async {
    if (_unverifiedCount <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi Semua Member'),
        content: Text('Yakin verifikasi semua member yang belum verified? ($_unverifiedCount member)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Verifikasi')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final result = await _service.verifyAllUnverified();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      _loadData(refresh: true);
    }
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MemberFormScreen()),
    );
    if (changed == true && mounted) {
      _loadData(refresh: true);
    }
  }

  Future<void> _openEdit(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemberFormScreen(memberId: id)),
    );
    if (changed == true && mounted) {
      _loadData(refresh: true);
    }
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: id)),
    );
    if (changed == true && mounted) {
      _loadData(refresh: true);
    }
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m) {
    final id = _toInt(m['id']);
    final active = m['is_active'] == true || m['status_aktif']?.toString() == '1';
    final name = m['nama_lengkap']?.toString() ?? m['name']?.toString() ?? '-';
    final memberId = m['member_id']?.toString() ?? m['costumers_id']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    active ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: active ? const Color(0xFF166534) : const Color(0xFF9A3412),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$memberId • ${m['email'] ?? '-'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '${m['mobile_phone'] ?? m['telepon'] ?? '-'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _miniPill('Point ${m['point_balance_formatted'] ?? '0'}', const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                _miniPill(m['tier_formatted']?.toString().toUpperCase() ?? 'SILVER', const Color(0xFFF3E8FF), const Color(0xFF6B21A8)),
                _miniPill(m['total_spending_formatted']?.toString() ?? 'Rp 0', const Color(0xFFDCFCE7), const Color(0xFF166534)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: id > 0 ? () => _openDetail(id) : null,
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('Detail'),
                ),
                OutlinedButton.icon(
                  onPressed: id > 0 ? () => _openEdit(id) : null,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                ),
                FilledButton.icon(
                  onPressed: id > 0 ? () => _toggleStatus(m) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: active ? const Color(0xFFF97316) : const Color(0xFF16A34A),
                  ),
                  icon: Icon(active ? Icons.person_off_outlined : Icons.person_outline, size: 17),
                  label: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Data Member',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Tambah Member', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari ID, nama, email, telepon...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _loadData(refresh: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _loadData(refresh: true),
                      child: const Text('Cari'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'inactive', child: Text('Tidak Aktif')),
                        ],
                        onChanged: (v) {
                          setState(() => _statusFilter = v ?? '');
                          _loadData(refresh: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _pointBalanceFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Saldo Point',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua')),
                          DropdownMenuItem(value: 'positive', child: Text('Positif')),
                          DropdownMenuItem(value: 'negative', child: Text('Negatif')),
                          DropdownMenuItem(value: 'zero', child: Text('Nol')),
                          DropdownMenuItem(value: 'high', child: Text('>=1000')),
                        ],
                        onChanged: (v) {
                          setState(() => _pointBalanceFilter = v ?? '');
                          _loadData(refresh: true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'Total Member',
                        value: _formatInt(_stats['total_members']),
                        icon: Icons.groups_2_outlined,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Member Aktif',
                        value: _formatInt(_stats['active_members']),
                        icon: Icons.verified_user_outlined,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Saldo Point',
                        value: _formatInt(_stats['total_point_balance']),
                        icon: Icons.stars_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _unverifiedCount > 0 ? _verifyAllUnverified : null,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: Text('Verifikasi Semua Member (${_formatInt(_unverifiedCount)})'),
                  ),
                ),
              ],
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
                              Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () => _loadData(refresh: true),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadData(refresh: true),
                        child: _members.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 140),
                                  Center(child: Text('Tidak ada data member')),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                itemCount: _members.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _members.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
                                    );
                                  }
                                  return _buildMemberCard(_members[index]);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
