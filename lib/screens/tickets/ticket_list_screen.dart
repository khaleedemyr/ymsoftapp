import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/ticket_service.dart';
import '../../services/auth_service.dart';
import '../../utils/ticket_due_date.dart';
import '../../utils/ticket_permissions.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import '../purchase_requisition_create_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_editor_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketService _svc = TicketService();
  final TextEditingController _search = TextEditingController();

  List<dynamic> _tickets = [];
  List<dynamic> _assignableUsers = [];
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _filterOptions;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  String _status = 'all';
  String _priority = 'all';
  String _category = 'all';
  String _division = 'all';
  String _outlet = 'all';
  String _paymentStatus = 'all';
  String _issueType = 'all';
  bool _canManageTickets = false;
  bool _viewAllOutlets = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
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

    final res = await _svc.getTickets(
      search: _search.text.trim(),
      status: _status,
      priority: _priority,
      category: _category,
      division: _division,
      outlet: _outlet,
      paymentStatus: _paymentStatus,
      issueType: _issueType,
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

    final list = res['tickets'] as List<dynamic>? ?? [];
    final pag = res['pagination'] as Map<String, dynamic>?;
    _lastPage = pag != null ? (pag['last_page'] as num?)?.toInt() ?? 1 : 1;
    final cur = pag != null ? (pag['current_page'] as num?)?.toInt() ?? 1 : 1;

    bool canManage = false;
    if (res.containsKey('can_manage_tickets')) {
      final v = res['can_manage_tickets'];
      canManage = v == true || v == 1;
    } else {
      final u = await AuthService().getUserData();
      canManage = TicketPermissions.userCanManage(u);
    }

    bool viewAllOutlets = true;
    if (res.containsKey('tickets_view_all_outlets')) {
      final v = res['tickets_view_all_outlets'];
      viewAllOutlets = v == true || v == 1;
    } else {
      final u = await AuthService().getUserData();
      final oid = u?['id_outlet'];
      viewAllOutlets = oid != null && int.tryParse(oid.toString()) == 1;
    }

    setState(() {
      if (reset) {
        _tickets = List.from(list);
        _statistics = res['statistics'] as Map<String, dynamic>?;
        _filterOptions = res['filter_options'] as Map<String, dynamic>?;
        _assignableUsers = res['assignable_users'] as List<dynamic>? ?? [];
        _canManageTickets = canManage;
        _viewAllOutlets = viewAllOutlets;
      } else {
        _tickets.addAll(list);
      }
      _page = cur;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  Future<void> _quickChangeStatus(Map<String, dynamic> ticket) async {
    final ticketId = (ticket['id'] as num?)?.toInt();
    if (ticketId == null || !mounted) return;

    var statuses = _filterOptions?['statuses'] as List<dynamic>? ?? [];
    if (statuses.isEmpty) {
      final opt = await _svc.getFormOptions();
      if (!mounted || opt['success'] != true) return;
      statuses = opt['statuses'] as List<dynamic>? ?? [];
    }
    if (statuses.isEmpty || !mounted) return;

    int? picked = (ticket['status_id'] as num?)?.toInt();
    if (picked == null && ticket['status'] is Map) {
      picked = ((ticket['status'] as Map)['id'] as num?)?.toInt();
    }

    final initialId = picked;
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int? sel = initialId;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Ubah status'),
              content: DropdownButtonFormField<int>(
                value: sel,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: statuses
                    .map((s) {
                      final m = s as Map<String, dynamic>;
                      return DropdownMenuItem<int>(
                        value: (m['id'] as num).toInt(),
                        child: Text(m['name']?.toString() ?? ''),
                      );
                    })
                    .toList(),
                onChanged: (v) => setSt(() => sel = v),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                FilledButton(
                  onPressed: sel == null ? null : () => Navigator.pop(ctx, sel),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    if (chosen == null || chosen == initialId || !mounted) return;

    final res = await _svc.updateStatus(ticketId, chosen);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status diperbarui')));
      _load(reset: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal ubah status')),
      );
    }
  }

  Future<void> _openCreateTicket() async {
    final ok = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TicketEditorScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
    if (ok == true && mounted) _load(reset: true);
  }

  int? _ticketDivisiId(Map<String, dynamic> t) {
    final raw = t['divisi_id'];
    if (raw is num) return raw.toInt();
    if (raw != null) return int.tryParse(raw.toString());
    if (t['divisi'] is Map) {
      final m = t['divisi'] as Map;
      final id = m['id'];
      if (id is num) return id.toInt();
      return int.tryParse(id?.toString() ?? '');
    }
    return null;
  }

  Future<void> _openTicketDetail(int id) async {
    final ok = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TicketDetailScreen(ticketId: id),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
    if (ok == true && mounted) _load(reset: true);
  }

  Future<void> _openTicketEdit(Map<String, dynamic> t) async {
    final id = (t['id'] as num?)?.toInt();
    if (id == null) return;
    final r = await _svc.getTicket(id);
    if (!mounted) return;
    if (r['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message']?.toString() ?? 'Gagal memuat ticket')),
      );
      return;
    }
    final full = r['ticket'] as Map<String, dynamic>?;
    if (full == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TicketEditorScreen(initialTicket: full)),
    );
    if (ok == true && mounted) _load(reset: true);
  }

  Future<void> _openAssignForTicket(Map<String, dynamic> ticket) async {
    final ticketId = (ticket['id'] as num?)?.toInt();
    if (ticketId == null) return;
    final divisiId = _ticketDivisiId(ticket);
    var users = _assignableUsers;
    if (divisiId != null) {
      final filtered = users.where((u) {
        final m = u as Map<String, dynamic>;
        final du = m['division_id'];
        return du != null && du.toString() == divisiId.toString();
      }).toList();
      if (filtered.isNotEmpty) users = filtered;
    }

    final assigned = ticket['assigned_users'] as List<dynamic>? ?? [];
    final pre = assigned.map((u) => (u['id'] as num).toInt()).toSet();
    final sel = Set<int>.from(pre);
    int? primaryId = () {
      for (final u in assigned) {
        final m = u as Map<String, dynamic>;
        final piv = m['pivot'];
        if (piv is Map && (piv['is_primary'] == true || piv['is_primary'] == 1)) {
          return (m['id'] as num).toInt();
        }
      }
      return pre.isEmpty ? null : pre.first;
    }();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text('Assign tim · ${ticket['ticket_number'] ?? ''}'),
            content: SizedBox(
              width: double.maxFinite,
              child: users.isEmpty
                  ? const Text('Tidak ada user tersedia')
                  : ListView(
                      shrinkWrap: true,
                      children: users.map((u) {
                        final m = u as Map<String, dynamic>;
                        final id = (m['id'] as num).toInt();
                        final name = m['nama_lengkap']?.toString() ?? '';
                        final checked = sel.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(name),
                          secondary: Radio<int>(
                            value: id,
                            groupValue: primaryId,
                            onChanged: !checked
                                ? null
                                : (v) => setSt(() => primaryId = v),
                          ),
                          onChanged: (v) {
                            setSt(() {
                              if (v == true) {
                                sel.add(id);
                                primaryId ??= id;
                              } else {
                                sel.remove(id);
                                if (primaryId == id) {
                                  primaryId = sel.isEmpty ? null : sel.first;
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                onPressed: sel.isEmpty ? null : () => Navigator.pop(ctx, true),
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || sel.isEmpty) {
      if (confirmed == true && sel.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal satu user')));
      }
      return;
    }
    final ids = sel.toList();
    final pic = primaryId != null && sel.contains(primaryId!) ? primaryId! : ids.first;
    final res = await _svc.assignTeam(ticketId, userIds: ids, primaryUserId: pic);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Team di-assign')),
      );
      _load(reset: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal assign')),
      );
    }
  }

  Future<void> _openCreatePaymentForTicket(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] as num?)?.toInt();
    if (id == null) return;
    final numStr = ticket['ticket_number']?.toString().trim() ?? '';
    final title = ticket['title']?.toString().trim() ?? '';
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseRequisitionCreateScreen(
          initialTicketId: id,
          initialTicketNumber: numStr.isEmpty ? null : numStr,
          initialTicketTitle: title.isEmpty ? null : title,
        ),
      ),
    );
    if (mounted) _load(reset: true);
  }

  Future<void> _deleteTicketRow(Map<String, dynamic> ticket) async {
    final ticketId = (ticket['id'] as num?)?.toInt();
    final numStr = ticket['ticket_number']?.toString() ?? '';
    if (ticketId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus ticket?'),
        content: Text('Yakin ingin menghapus ticket $numStr?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _svc.deleteTicket(ticketId);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Terhapus')));
      _load(reset: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Gagal menghapus')),
      );
    }
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterSheet(
        status: _status,
        priority: _priority,
        category: _category,
        division: _division,
        outlet: _outlet,
        paymentStatus: _paymentStatus,
        issueType: _issueType,
        viewAllOutlets: _viewAllOutlets,
        options: _filterOptions,
        onApply: (s, p, c, d, o, pay, it) {
          setState(() {
            _status = s;
            _priority = p;
            _category = c;
            _division = d;
            _outlet = o;
            _paymentStatus = pay;
            _issueType = it;
          });
          Navigator.pop(ctx);
          _load(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ticket',
      showDrawer: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicket,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Ticket baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _buildHeroActions(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Cari nomor, judul, deskripsi…',
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _load(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _openFilters,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.tune_rounded, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_statistics != null) _buildStats(),
          Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator(size: 36, color: Color(0xFF4F46E5), useLogo: false))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              TextButton(onPressed: () => _load(reset: true), child: const Text('Coba lagi')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF4F46E5),
                        onRefresh: () => _load(reset: true),
                        child: _tickets.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('Belum ada ticket')),
                                ],
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                                    _load();
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  itemCount: _tickets.length + (_loadingMore ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    if (i >= _tickets.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    }
                                    final t = _tickets[i] as Map<String, dynamic>;
                                    final tid = (t['id'] as num?)?.toInt();
                                    if (tid == null) return const SizedBox.shrink();
                                    return _TicketCard(
                                      data: t,
                                      canManageTickets: _canManageTickets,
                                      onOpenDetail: () => _openTicketDetail(tid),
                                      onChangeStatus: () => _quickChangeStatus(t),
                                      onEdit: () => _openTicketEdit(t),
                                      onAssign: () => _openAssignForTicket(t),
                                      onPayment: () => _openCreatePaymentForTicket(t),
                                      onDelete: () => _deleteTicketRow(t),
                                    );
                                  },
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF4F46E5),
            Color(0xFF4338CA),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticketing System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ticket, prioritas, outlet & SLA — sama seperti di web.',
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final s = _statistics!;
    int v(String k) => (s[k] as num?)?.toInt() ?? 0;
    final chips = [
      ('Semua', v('total'), 'all', const Color(0xFF64748B)),
      ('Open', v('open'), 'open', const Color(0xFF0EA5E9)),
      ('Proses', v('in_progress'), 'in_progress', const Color(0xFFF59E0B)),
      ('Resolved', v('resolved'), 'resolved', const Color(0xFF10B981)),
      ('Closed', v('closed'), 'closed', const Color(0xFF94A3B8)),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          final active = _status == c.$3;
          return FilterChip(
            label: Text('${c.$1} · ${c.$2}'),
            selected: active,
            onSelected: (_) {
              setState(() => _status = c.$3);
              _load(reset: true);
            },
            selectedColor: c.$4.withOpacity(0.2),
            checkmarkColor: c.$4,
            labelStyle: TextStyle(
              color: active ? c.$4 : const Color(0xFF475569),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            side: BorderSide(color: active ? c.$4 : Colors.grey.shade200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canManageTickets;
  final VoidCallback onOpenDetail;
  final VoidCallback onChangeStatus;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _TicketCard({
    required this.data,
    required this.canManageTickets,
    required this.onOpenDetail,
    required this.onChangeStatus,
    required this.onEdit,
    required this.onAssign,
    required this.onPayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ticketNum = data['ticket_number']?.toString() ?? '';
    final title = data['title']?.toString() ?? '';
    final status = data['status'] is Map ? data['status']['name']?.toString() : null;
    final statusSlug = data['status'] is Map ? data['status']['slug']?.toString() : null;
    final priority = data['priority'] is Map ? data['priority']['name']?.toString() : null;
    final level = data['priority'] is Map ? (data['priority']['level'] as num?)?.toInt() : null;
    final category = data['category'] is Map ? data['category']['name']?.toString() : null;
    final divisi = data['divisi'] is Map ? data['divisi']['nama_divisi']?.toString() : null;
    final outlet = data['outlet'] is Map ? data['outlet']['nama_outlet']?.toString() : null;
    final due = data['due_date']?.toString();
    final comments = (data['comments_count'] as num?)?.toInt() ?? 0;
    final creator = data['creator'] is Map ? data['creator'] as Map<String, dynamic> : null;
    final assigned = data['assigned_users'] as List<dynamic>? ?? [];
    final issueRaw = data['issue_type']?.toString();
    final issueLabel = issueRaw != null && issueRaw.isNotEmpty ? issueRaw : null;
    final createdAt = data['created_at']?.toString();
    Color bar;
    if (level != null && level >= 4) {
      bar = const Color(0xFFDC2626);
    } else if (level != null && level >= 3) {
      bar = const Color(0xFFF97316);
    } else {
      bar = const Color(0xFF4F46E5);
    }

    Color statusBg;
    switch (statusSlug) {
      case 'open':
        statusBg = const Color(0xFFDBEAFE);
        break;
      case 'in_progress':
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'resolved':
        statusBg = const Color(0xFFD1FAE5);
        break;
      default:
        statusBg = const Color(0xFFE2E8F0);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: onOpenDetail,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _UserAvatar(user: creator, radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              flex: 2,
                                              child: Text(
                                                ticketNum,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                  color: Color(0xFF4F46E5),
                                                  letterSpacing: 0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (status != null)
                                              Flexible(
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: canManageTickets ? onChangeStatus : null,
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusBg,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              status,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                                            ),
                                                          ),
                                                          if (canManageTickets) ...[
                                                            const SizedBox(width: 4),
                                                            Icon(
                                                              Icons.arrow_drop_down_rounded,
                                                              size: 18,
                                                              color: Colors.grey.shade800,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (issueLabel != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              issueLabel,
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                            ),
                                          ),
                                        ],
                                        if (creator != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            creator['nama_lengkap']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                        if (createdAt != null && createdAt.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            _fmtCreated(createdAt),
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  height: 1.25,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (category != null || priority != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (category != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          category,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                        ),
                                      ),
                                    if (priority != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          priority,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (outlet != null || divisi != null) ...[
                                const SizedBox(height: 8),
                                if (outlet != null)
                                  Row(
                                    children: [
                                      Icon(Icons.store_rounded, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          outlet,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (divisi != null) ...[
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Text(
                                      divisi,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (assigned.isNotEmpty) ...[
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _AssigneeAvatarStack(users: assigned),
                                              if (assigned.length > 3)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: Text(
                                                    '+${assigned.length - 3}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _primaryAssigneeName(assigned),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                            ),
                                          ),
                                        ] else
                                          Expanded(
                                            child: Text(
                                              'Belum di-assign',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (due != null && due.isNotEmpty)
                                    Flexible(
                                      child: TicketDueDateRow(
                                        dueIso: due,
                                        statusSlug: statusSlug,
                                        dateLabel: _fmtDate(due),
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _paymentSummaryLine(data),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text('$comments', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _aksiIcon(
                              tooltip: 'Lihat',
                              icon: Icons.visibility_rounded,
                              color: const Color(0xFF2563EB),
                              onTap: onOpenDetail,
                            ),
                            if (canManageTickets) ...[
                              _aksiIcon(
                                tooltip: 'Edit',
                                icon: Icons.edit_rounded,
                                color: const Color(0xFF16A34A),
                                onTap: onEdit,
                              ),
                              _aksiIcon(
                                tooltip: 'Assign tim',
                                icon: Icons.groups_rounded,
                                color: const Color(0xFF4F46E5),
                                onTap: onAssign,
                              ),
                              _aksiIcon(
                                tooltip: 'Payment (PR) — terisi nomor ticket',
                                icon: Icons.account_balance_wallet_outlined,
                                color: const Color(0xFF059669),
                                onTap: onPayment,
                              ),
                              _aksiIcon(
                                tooltip: 'Hapus',
                                icon: Icons.delete_outline_rounded,
                                color: const Color(0xFFDC2626),
                                onTap: onDelete,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aksiIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('d MMM yy', 'id_ID').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _fmtCreated(String iso) {
    try {
      return DateFormat('d MMM yyyy · HH:mm', 'id_ID').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _paymentSummaryLine(Map<String, dynamic> d) {
    final p = d['payment_info'];
    if (p is! Map) return 'Belum ada PR / payment';
    final total = (p['total_pr'] as num?)?.toInt() ?? 0;
    if (total == 0) return 'Belum ada PR / payment';
    final paid = (p['total_paid_pr'] as num?)?.toInt() ?? 0;
    final proc = (p['total_processing_pr'] as num?)?.toInt() ?? 0;
    if (paid > 0) return 'PR: $total · Paid: $paid';
    if (proc > 0) return 'PR: $total · Payment proses';
    return 'PR: $total';
  }

  String _primaryAssigneeName(List<dynamic> assigned) {
    for (final u in assigned) {
      if (u is! Map) continue;
      final m = Map<String, dynamic>.from(u);
      final piv = m['pivot'];
      if (piv is Map && (piv['is_primary'] == true || piv['is_primary'] == 1)) {
        return m['nama_lengkap']?.toString() ?? '';
      }
    }
    final first = assigned.isNotEmpty ? assigned.first : null;
    if (first is Map) return Map<String, dynamic>.from(first)['nama_lengkap']?.toString() ?? '';
    return '';
  }
}

String? _ticketUserAvatarUrl(Map<String, dynamic>? u) {
  if (u == null) return null;
  final raw = u['avatar']?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  var n = raw.replaceFirst(RegExp(r'^/'), '');
  if (n.startsWith('storage/')) return '${AuthService.storageUrl}/$n';
  if (n.startsWith('public/')) {
    n = n.replaceFirst(RegExp(r'^public/'), '');
    return '${AuthService.storageUrl}/storage/$n';
  }
  return '${AuthService.storageUrl}/storage/$n';
}

String _ticketUserInitials(String? name) {
  final s = name?.trim() ?? '';
  if (s.isEmpty) return '?';
  final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) {
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    return ('$a$b').toUpperCase();
  }
  if (s.length >= 2) return s.substring(0, 2).toUpperCase();
  return s[0].toUpperCase();
}

class _UserAvatar extends StatelessWidget {
  final Map<String, dynamic>? user;
  final double radius;

  const _UserAvatar({this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final url = _ticketUserAvatarUrl(user);
    final name = user?['nama_lengkap']?.toString();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDBEAFE),
      child: url != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Text(
                  _ticketUserInitials(name),
                  style: TextStyle(
                    fontSize: radius * 0.55,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            )
          : Text(
              _ticketUserInitials(name),
              style: TextStyle(
                fontSize: radius * 0.55,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1D4ED8),
              ),
            ),
    );
  }
}

class _AssigneeAvatarStack extends StatelessWidget {
  final List<dynamic> users;

  const _AssigneeAvatarStack({required this.users});

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    const step = 14.0;
    final show = users.take(3).toList();
    if (show.isEmpty) return const SizedBox.shrink();
    final w = size + (show.length - 1) * step;
    return SizedBox(
      width: w,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < show.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: _UserAvatar(
                  user: show[i] is Map<String, dynamic> ? show[i] as Map<String, dynamic> : null,
                  radius: size / 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String status;
  final String priority;
  final String category;
  final String division;
  final String outlet;
  final String paymentStatus;
  final String issueType;
  final bool viewAllOutlets;
  final Map<String, dynamic>? options;
  final void Function(String, String, String, String, String, String, String) onApply;

  const _FilterSheet({
    required this.status,
    required this.priority,
    required this.category,
    required this.division,
    required this.outlet,
    required this.paymentStatus,
    required this.issueType,
    required this.viewAllOutlets,
    required this.options,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _priority;
  late String _category;
  late String _division;
  late String _outlet;
  late String _paymentStatus;
  late String _issueType;

  @override
  void initState() {
    super.initState();
    _priority = widget.priority;
    _category = widget.category;
    _division = widget.division;
    _outlet = widget.outlet;
    _paymentStatus = widget.paymentStatus;
    _issueType = widget.issueType;
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.options;
    final priorities = opts?['priorities'] as List<dynamic>? ?? [];
    final categories = opts?['categories'] as List<dynamic>? ?? [];
    final divisions = opts?['divisions'] as List<dynamic>? ?? [];
    final outlets = opts?['outlets'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Filter lanjutan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _dd('Prioritas', _priority, [
                const MapEntry('all', 'Semua'),
                ...priorities.map((p) {
                  final m = p as Map<String, dynamic>;
                  return MapEntry('${m['id']}', m['name']?.toString() ?? '');
                }),
              ], (v) => setState(() => _priority = v)),
              _dd('Kategori', _category, [
                const MapEntry('all', 'Semua'),
                ...categories.map((p) {
                  final m = p as Map<String, dynamic>;
                  return MapEntry('${m['id']}', m['name']?.toString() ?? '');
                }),
              ], (v) => setState(() => _category = v)),
              _dd('Divisi', _division, [
                const MapEntry('all', 'Semua'),
                ...divisions.map((p) {
                  final m = p as Map<String, dynamic>;
                  return MapEntry('${m['id']}', m['nama_divisi']?.toString() ?? '');
                }),
              ], (v) => setState(() => _division = v)),
              if (widget.viewAllOutlets)
                _dd('Outlet', _outlet, [
                  const MapEntry('all', 'Semua'),
                  ...outlets.map((p) {
                    final m = p as Map<String, dynamic>;
                    final id = m['id_outlet'] ?? m['id'];
                    return MapEntry('$id', m['nama_outlet']?.toString() ?? '');
                  }),
                ], (v) => setState(() => _outlet = v)),
              _dd(
                'Jenis issue',
                _issueType,
                const [
                  MapEntry('all', 'Semua'),
                  MapEntry('defect', 'Defect'),
                  MapEntry('ops_issue', 'Ops Issue'),
                ],
                (v) => setState(() => _issueType = v),
              ),
              _dd('Payment / PR', _paymentStatus, const [
                MapEntry('all', 'Semua'),
                MapEntry('no_pr', 'Tanpa PR'),
                MapEntry('with_pr', 'Ada PR'),
                MapEntry('paid', 'PR lunas'),
                MapEntry('on_process', 'PR proses bayar'),
              ], (v) => setState(() => _paymentStatus = v)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => widget.onApply(
                  widget.status,
                  _priority,
                  _category,
                  _division,
                  _outlet,
                  _paymentStatus,
                  _issueType,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Terapkan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dd(String label, String value, List<MapEntry<String, String>> items, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.isEmpty ? e.key : e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
