import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/guest_comment_service.dart';
import 'guest_comment_form_screen.dart';
import 'guest_comment_upload_screen.dart';

void _openGuestCommentFormImagePreview(BuildContext context, String url) {
  if (url.isEmpty) return;
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Daftar Guest Comment (OCR) — selaras informasi & aksi dengan ERP web.
class GuestCommentListScreen extends StatefulWidget {
  const GuestCommentListScreen({super.key});

  @override
  State<GuestCommentListScreen> createState() => _GuestCommentListScreenState();
}

class _GuestCommentListScreenState extends State<GuestCommentListScreen> {
  final _service = GuestCommentService();
  final _searchCtl = TextEditingController();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  static const int _perPage = 15;

  String _statusFilter = '';
  String? _idOutletFilter;
  String _dateFrom = '';
  String _dateTo = '';

  bool _canChooseOutlet = false;
  List<dynamic> _outlets = [];
  Map<String, dynamic>? _lockedOutlet;
  bool _metaFromApi = false;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    await _fetchPage(1, replace: true);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _fetchPage(int page, {bool replace = false}) async {
    final res = await _service.list(
      search: _searchCtl.text.trim(),
      status: _statusFilter,
      idOutlet: _idOutletFilter,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      page: page,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      if (replace) {
        setState(() {
          _error = res['message']?.toString() ?? 'Gagal memuat';
          _items.clear();
        });
      }
      return;
    }
    _canChooseOutlet = res['can_choose_outlet'] == true;
    _outlets = res['outlets'] as List<dynamic>? ?? [];
    final lo = res['locked_outlet'];
    _lockedOutlet = lo is Map ? Map<String, dynamic>.from(lo as Map) : null;
    _metaFromApi = true;
    final forms = res['forms'];
    if (forms is! Map) return;
    final data = forms['data'];
    final last = forms['last_page'];
    _lastPage = last is int ? last : int.tryParse('$last') ?? 1;
    if (data is List) {
      final next = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        if (replace) {
          _items
            ..clear()
            ..addAll(next);
        } else {
          _items.addAll(next);
        }
        _page = page;
        _error = null;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    await _fetchPage(_page + 1, replace: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _pickDateFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateFrom.isEmpty
          ? DateTime.now()
          : DateTime.tryParse(_dateFrom) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() => _dateFrom = DateFormat('yyyy-MM-dd').format(d));
      _refresh();
    }
  }

  Future<void> _pickDateTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTo.isEmpty
          ? DateTime.now()
          : DateTime.tryParse(_dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() => _dateTo = DateFormat('yyyy-MM-dd').format(d));
      _refresh();
    }
  }

  void _clearDateRange() {
    setState(() {
      _dateFrom = '';
      _dateTo = '';
    });
    _refresh();
  }

  void _setStatusFilter(String value) {
    setState(() => _statusFilter = value);
    _refresh();
  }

  Future<void> _openItem(Map<String, dynamic> row) async {
    final id = row['id'];
    final intId = id is int ? id : (id as num).toInt();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GuestCommentFormScreen(formId: intId),
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'];
    final intId = id is int ? id : (id as num).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus guest comment?'),
        content: const Text('Data dan foto formulir akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _service.deleteForm(intId);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terhapus'), behavior: SnackBarBehavior.floating),
      );
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menghapus'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Guest Comment (OCR)'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const GuestCommentUploadScreen()),
          );
          if (r == true && mounted) _refresh();
        },
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Foto baru'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Column(
        children: [
          if (_metaFromApi && !_canChooseOutlet && _lockedOutlet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_rounded, color: Colors.blue.shade800, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hanya data outlet: ${_lockedOutlet!['nama_outlet'] ?? '—'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_metaFromApi && !_canChooseOutlet && _lockedOutlet == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Akun tidak memiliki outlet — daftar kosong.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Cari nama, telepon, komentar, sumber marketing…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Terapkan pencarian',
                  onPressed: _refresh,
                ),
              ),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GuestCommentFilterCard(
              expanded: _filtersExpanded,
              onToggleExpanded: () =>
                  setState(() => _filtersExpanded = !_filtersExpanded),
              statusFilter: _statusFilter,
              idOutletFilter: _idOutletFilter,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              canChooseOutlet: _canChooseOutlet,
              outlets: _outlets,
              onStatus: _setStatusFilter,
              onOutletChanged: (v) {
                setState(() => _idOutletFilter = v);
                _refresh();
              },
              onPickFrom: _pickDateFrom,
              onPickTo: _pickDateTo,
              onClearDates: _clearDateRange,
              onApplySearch: _refresh,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Rating: S Service, F Food, B Beverage, C Cleanliness, T Staff, V Value — ★ 1–4 = Poor → Excellent',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.25),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _refresh,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 56, color: Colors.black26),
                                  SizedBox(height: 12),
                                  Center(child: Text('Belum ada data')),
                                ],
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels >
                                      n.metrics.maxScrollExtent - 200) {
                                    _loadMore();
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 88),
                                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                                  itemBuilder: (ctx, i) {
                                    if (i >= _items.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return _GuestCard(
                                      row: _items[i],
                                      rowNumber: i + 1,
                                      onDetail: () => _openItem(_items[i]),
                                      onVerify: _items[i]['status']?.toString() !=
                                              'verified'
                                          ? () => _openItem(_items[i])
                                          : null,
                                      onDelete: () => _confirmDelete(_items[i]),
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
}

String _guestCommentDateChipLabel(String ymd) {
  if (ymd.isEmpty) return 'Pilih';
  try {
    return DateFormat.yMMMd('id_ID').format(DateTime.parse(ymd));
  } catch (_) {
    return ymd;
  }
}

/// Panel filter di index (selaras ERP: status, outlet, tanggal, Terapkan).
class _GuestCommentFilterCard extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final String statusFilter;
  final String? idOutletFilter;
  final String dateFrom;
  final String dateTo;
  final bool canChooseOutlet;
  final List<dynamic> outlets;
  final void Function(String status) onStatus;
  final void Function(String? outletId) onOutletChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;
  final VoidCallback onApplySearch;

  const _GuestCommentFilterCard({
    required this.expanded,
    required this.onToggleExpanded,
    required this.statusFilter,
    required this.idOutletFilter,
    required this.dateFrom,
    required this.dateTo,
    required this.canChooseOutlet,
    required this.outlets,
    required this.onStatus,
    required this.onOutletChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
    required this.onApplySearch,
  });

  String _collapsedHint() {
    final parts = <String>[];
    if (statusFilter.isEmpty) {
      parts.add('Semua status');
    } else if (statusFilter == 'pending_verification') {
      parts.add('Menunggu verifikasi');
    } else if (statusFilter == 'verified') {
      parts.add('Terverifikasi');
    }
    if (canChooseOutlet) {
      if (idOutletFilter == null || idOutletFilter!.isEmpty) {
        parts.add('Semua outlet');
      } else {
        String? outletName;
        for (final o in outlets) {
          final m = o as Map<String, dynamic>;
          if (m['id_outlet'].toString() == idOutletFilter) {
            outletName = m['nama_outlet']?.toString();
            break;
          }
        }
        parts.add(
          (outletName != null && outletName.isNotEmpty) ? outletName : 'Outlet terpilih',
        );
      }
    }
    if (dateFrom.isNotEmpty || dateTo.isNotEmpty) {
      final a = dateFrom.isEmpty ? '…' : _guestCommentDateChipLabel(dateFrom);
      final b = dateTo.isEmpty ? '…' : _guestCommentDateChipLabel(dateTo);
      parts.add('$a – $b');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, 10, 14, expanded ? 14 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          if (!expanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              _collapsedHint(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      key: const ValueKey('filter-body'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
            const SizedBox(height: 8),
            Text(
              'Status',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: statusFilter.isEmpty,
                  onSelected: (v) {
                    if (v) onStatus('');
                  },
                  showCheckmark: false,
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue.shade800,
                ),
                FilterChip(
                  label: const Text('Menunggu verifikasi'),
                  selected: statusFilter == 'pending_verification',
                  onSelected: (v) {
                    if (v) onStatus('pending_verification');
                  },
                  showCheckmark: false,
                  selectedColor: Colors.amber.shade100,
                ),
                FilterChip(
                  label: const Text('Terverifikasi'),
                  selected: statusFilter == 'verified',
                  onSelected: (v) {
                    if (v) onStatus('verified');
                  },
                  showCheckmark: false,
                  selectedColor: Colors.green.shade100,
                ),
              ],
            ),
            if (canChooseOutlet) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: idOutletFilter,
                decoration: InputDecoration(
                  labelText: 'Outlet',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Semua outlet'),
                  ),
                  ...outlets.map((o) {
                    final m = o as Map<String, dynamic>;
                    final id = m['id_outlet'].toString();
                    return DropdownMenuItem<String?>(
                      value: id,
                      child: Text(
                        m['nama_outlet']?.toString() ?? id,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: onOutletChanged,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Periode dibuat',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickFrom,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      dateFrom.isEmpty ? 'Dari' : _guestCommentDateChipLabel(dateFrom),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      foregroundColor: const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickTo,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      dateTo.isEmpty ? 'Sampai' : _guestCommentDateChipLabel(dateTo),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      foregroundColor: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            if (dateFrom.isNotEmpty || dateTo.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onClearDates,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Hapus periode'),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              onPressed: onApplySearch,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Terapkan pencarian'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ——— Avatar & URL (selaras ERP /storage + default) ———

String _userAvatarUrl(Map<String, dynamic>? user) {
  final raw = user?['avatar']?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return '${AuthService.storageUrl}/images/avatar-default.png';
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('/')) return '${AuthService.storageUrl}$raw';
  return '${AuthService.storageUrl}/storage/$raw';
}

String _userInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  String ch(String s) {
    if (s.isEmpty) return '';
    final r = s.runes.first;
    return String.fromCharCode(r);
  }

  if (p.length == 1) return ch(p[0]).toUpperCase();
  return '${ch(p.first)}${ch(p.last)}'.toUpperCase();
}

class _UserAvatar extends StatelessWidget {
  final Map<String, dynamic>? user;
  final double size;

  const _UserAvatar({
    required this.user,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final url = _userAvatarUrl(user);
    final hasFile = user?['avatar'] != null &&
        user!['avatar'].toString().trim().isNotEmpty;
    final name = user?['nama_lengkap']?.toString();
    final child = hasFile
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _initialsFallback(name),
            ),
          )
        : _initialsFallback(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAvatarPreview(context, url, name),
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _initialsFallback(String? name) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFBAE6FD), Color(0xFF93C5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _userInitials(name),
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E3A5F),
        ),
      ),
    );
  }
}

void _openAvatarPreview(BuildContext context, String url, String? name) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(name ?? 'Foto profil'),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

String _formatDt(dynamic v) {
  if (v == null) return '—';
  try {
    final d = DateTime.parse(v.toString());
    return DateFormat('dd/MM/yyyy, HH:mm', 'id_ID').format(d.toLocal());
  } catch (_) {
    return v.toString();
  }
}

class _GuestCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final int rowNumber;
  final VoidCallback onDetail;
  final VoidCallback? onVerify;
  final VoidCallback onDelete;

  const _GuestCard({
    required this.row,
    required this.rowNumber,
    required this.onDetail,
    this.onVerify,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = row['guest_name']?.toString() ?? '—';
    final addr = row['guest_address']?.toString() ?? '';
    final phone = row['guest_phone']?.toString() ?? '';
    final marketing = row['marketing_source']?.toString() ?? '';
    final imageUrl = row['image_url']?.toString() ?? '';
    final comment = row['comment_text']?.toString() ?? '';
    final outlet = row['outlet'] as Map<String, dynamic>?;
    final outletName = outlet?['nama_outlet']?.toString();
    final verified = row['status']?.toString() == 'verified';
    final creator = row['creator'] as Map<String, dynamic>?;
    final verifier = row['verifier'] as Map<String, dynamic>?;
    final createdAt = row['created_at'];
    final verifiedAt = row['verified_at'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: Colors.black12,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            _openGuestCommentFormImagePreview(context, imageUrl),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 44,
                          height: 62,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 44,
                            height: 62,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 44,
                            height: 62,
                            color: Colors.grey.shade200,
                            child: Icon(Icons.broken_image_outlined,
                                size: 22, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No. $rowNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: verified
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              verified ? 'Terverifikasi' : 'Menunggu verifikasi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: verified
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (addr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          addr,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_android_rounded,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (marketing.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 14, color: Colors.indigo.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                marketing,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (addr.isEmpty && phone.isEmpty && marketing.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Alamat / HP belum diisi',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (outletName != null && outletName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                outletName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Komentar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _RatingStrip(row: row),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                      _PersonRow(
                        label: 'Pencatat',
                        user: creator,
                        sub: 'Dibuat: ${_formatDt(createdAt)}',
                      ),
                      if (verified) ...[
                        const SizedBox(height: 10),
                        _PersonRow(
                          label: 'Verifikasi',
                          user: verifier,
                          sub: _formatDt(verifiedAt),
                          subIsBold: true,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onVerify != null)
                      IconButton(
                        onPressed: onVerify,
                        icon: const Icon(Icons.fact_check_rounded),
                        color: const Color(0xFF2563EB),
                        tooltip: 'Verifikasi',
                      ),
                    IconButton(
                      onPressed: onDetail,
                      icon: const Icon(Icons.visibility_rounded),
                      color: const Color(0xFF475569),
                      tooltip: 'Detail',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: const Color(0xFFDC2626),
                      tooltip: 'Hapus',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? user;
  final String sub;
  final bool subIsBold;

  const _PersonRow({
    required this.label,
    required this.user,
    required this.sub,
    this.subIsBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserAvatar(
          user: user,
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                user?['nama_lengkap']?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: subIsBold ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingStrip extends StatelessWidget {
  final Map<String, dynamic> row;

  const _RatingStrip({required this.row});

  int _stars(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'poor':
        return 1;
      case 'average':
        return 2;
      case 'good':
        return 3;
      case 'excellent':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      ('rating_service', 'S'),
      ('rating_food', 'F'),
      ('rating_beverage', 'B'),
      ('rating_cleanliness', 'C'),
      ('rating_staff', 'T'),
      ('rating_value', 'V'),
    ];
    final filled = <int>[];
    for (final e in keys) {
      final n = _stars(row[e.$1]?.toString());
      if (n > 0) filled.add(n);
    }
    final double? avg =
        filled.isEmpty ? null : filled.reduce((a, b) => a + b) / filled.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tooltip(
              message:
                  'Rata-rata ${filled.length} aspek terisi (skala 1–4)',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  Text(
                    ' / 4 avg',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: keys.map((e) {
            final n = _stars(row[e.$1]?.toString());
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.$2,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                ...List.generate(
                  4,
                  (i) => Icon(
                    i < n ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 15,
                    color: i < n ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
