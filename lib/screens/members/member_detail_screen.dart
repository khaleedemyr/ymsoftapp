import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/member_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'member_form_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final int memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberService _service = MemberService();
  Map<String, dynamic>? _member;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _fmtNum(dynamic value) {
    return NumberFormat('#,##0', 'id_ID').format(_toInt(value));
  }

  String _fmtDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _fmtDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getMember(widget.memberId);
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat detail';
        _loading = false;
      });
      return;
    }
    final m = result['member'] is Map ? Map<String, dynamic>.from(result['member'] as Map) : <String, dynamic>{};
    setState(() {
      _member = m;
      _loading = false;
    });
  }

  Future<void> _toggleStatus() async {
    if (_processing) return;
    final m = _member;
    if (m == null) return;
    final id = _toInt(m['id']);
    if (id <= 0) return;

    final active = m['is_active'] == true || m['status_aktif']?.toString() == '1';
    final action = active ? 'nonaktifkan' : 'aktifkan';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} member?'),
        content: Text('Yakin ingin $action member ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing = true);
    final result = await _service.toggleStatus(id);
    if (!mounted) return;
    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      await _loadDetail();
      Navigator.pop(context, true);
    }
  }

  Future<void> _verifyEmail() async {
    if (_processing) return;
    final m = _member;
    if (m == null) return;
    final id = _toInt(m['id']);
    if (id <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi Email'),
        content: const Text('Yakin ingin verifikasi email member ini secara manual?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verifikasi')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing = true);
    final result = await _service.verifyEmail(id);
    if (!mounted) return;
    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
    if (result['success'] == true) {
      await _loadDetail();
      Navigator.pop(context, true);
    }
  }

  Future<void> _changePassword() async {
    if (_processing) return;
    final m = _member;
    if (m == null) return;
    final id = _toInt(m['id']);
    if (id <= 0) return;

    final passwordCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordCtl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password baru'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Konfirmasi password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ubah')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final password = passwordCtl.text.trim();
    final confirm = confirmCtl.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Password minimal 6 karakter'), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Konfirmasi password tidak cocok'), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    setState(() => _processing = true);
    final result = await _service.changePassword(id: id, password: password, confirmPassword: confirm);
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Berhasil' : 'Gagal')),
        backgroundColor: result['success'] == true ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _showTransactions() async {
    final id = _toInt(_member?['id']);
    if (id <= 0) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MemberDataDialog(
        title: 'Transaksi & Point',
        loader: () => _service.getTransactions(id),
        itemBuilder: (item) {
          final point = item['point']?.toString() ?? '0';
          final desc = item['description']?.toString() ?? '-';
          final type = item['type_text']?.toString() ?? '-';
          final date = item['created_at']?.toString() ?? '';
          final bill = item['no_bill']?.toString() ?? '-';
          return ListTile(
            dense: true,
            title: Text('$type • $point point'),
            subtitle: Text('$desc\nBill: $bill\n$date'),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Future<void> _showPreferences() async {
    final id = _toInt(_member?['id']);
    if (id <= 0) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MemberDataDialog(
        title: 'Menu Favorit',
        loader: () => _service.getPreferences(id),
        listKey: 'preferences',
        itemBuilder: (item) {
          final menu = item['menu_name']?.toString() ?? '-';
          final count = item['order_count']?.toString() ?? '0';
          final total = item['total_spent_formatted']?.toString() ?? 'Rp 0';
          final last = item['last_ordered_formatted']?.toString() ?? '-';
          return ListTile(
            dense: true,
            title: Text(menu),
            subtitle: Text('Order: ${count}x • Total: $total\nTerakhir: $last'),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Future<void> _showTimeline() async {
    final id = _toInt(_member?['id']);
    if (id <= 0) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MemberDataDialog(
        title: 'Timeline Aktivitas',
        loader: () => _service.getVoucherTimeline(id),
        listKey: 'timeline',
        itemBuilder: (item) {
          final title = item['title']?.toString() ?? '-';
          final detail = item['voucher_name']?.toString() ??
              item['challenge_name']?.toString() ??
              item['reward_name']?.toString() ??
              item['description']?.toString() ??
              '-';
          final date = item['date_formatted']?.toString() ?? item['date']?.toString() ?? '-';
          return ListTile(
            dense: true,
            title: Text(title),
            subtitle: Text('$detail\n$date'),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Future<void> _openEdit() async {
    final id = _toInt(_member?['id']);
    if (id <= 0) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemberFormScreen(memberId: id)),
    );
    if (changed == true && mounted) {
      await _loadDetail();
      Navigator.pop(context, true);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _member ?? {};
    final active = m['is_active'] == true || m['status_aktif']?.toString() == '1';
    final emailVerified = m['email_verified_at'] != null;

    return AppScaffold(
      title: 'Detail Member',
      showDrawer: false,
      actions: [
        IconButton(
          onPressed: _processing ? null : _openEdit,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
        ),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 42, color: Colors.red.shade300),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _loadDetail,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['nama_lengkap']?.toString() ?? m['name']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['member_id']?.toString() ?? m['costumers_id']?.toString() ?? '-',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip(active ? 'Aktif' : 'Nonaktif', active ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5), active ? const Color(0xFF166534) : const Color(0xFF9A3412)),
                                  _chip(
                                    emailVerified ? 'Email Verified' : 'Belum Verify',
                                    emailVerified ? const Color(0xFFDBEAFE) : const Color(0xFFFEE2E2),
                                    emailVerified ? const Color(0xFF1E40AF) : const Color(0xFFB91C1C),
                                  ),
                                  _chip(
                                    (m['member_level']?.toString() ?? 'silver').toUpperCase(),
                                    const Color(0xFFF3E8FF),
                                    const Color(0xFF6B21A8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _infoRow('Email', m['email']?.toString() ?? '-'),
                              _infoRow('Telepon', m['mobile_phone']?.toString() ?? m['telepon']?.toString() ?? '-'),
                              _infoRow('Tanggal Lahir', _fmtDate(m['tanggal_lahir'])),
                              _infoRow('Jenis Kelamin', m['jenis_kelamin_text']?.toString() ?? '-'),
                              _infoRow('Pekerjaan', m['pekerjaan_name']?.toString() ?? m['occupation']?['name']?.toString() ?? '-'),
                              _infoRow('Saldo Point', _fmtNum(m['just_points'])),
                              _infoRow('Total Spending', 'Rp ${_fmtNum(m['total_spending'])}'),
                              _infoRow('Point Remainder', m['point_remainder']?.toString() ?? '0'),
                              _infoRow('Email Verified At', _fmtDateTime(m['email_verified_at'])),
                              _infoRow('Mobile Verified At', _fmtDateTime(m['mobile_verified_at'])),
                              _infoRow('Last Login', _fmtDateTime(m['last_login_at'])),
                              _infoRow('Created At', _fmtDateTime(m['created_at'])),
                              _infoRow('Updated At', _fmtDateTime(m['updated_at'])),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _processing ? null : _toggleStatus,
                            style: FilledButton.styleFrom(
                              backgroundColor: active ? const Color(0xFFF97316) : const Color(0xFF16A34A),
                            ),
                            icon: Icon(active ? Icons.person_off_outlined : Icons.person_outline),
                            label: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
                          ),
                          FilledButton.icon(
                            onPressed: _processing || emailVerified ? null : _verifyEmail,
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: const Text('Verifikasi Email'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _processing ? null : _changePassword,
                            icon: const Icon(Icons.key_outlined),
                            label: const Text('Ubah Password'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showTransactions,
                            icon: const Icon(Icons.account_balance_wallet_outlined),
                            label: const Text('Transaksi & Point'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showPreferences,
                            icon: const Icon(Icons.favorite_border_rounded),
                            label: const Text('Menu Favorit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showTimeline,
                            icon: const Icon(Icons.timeline_rounded),
                            label: const Text('Timeline Aktivitas'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MemberDataDialog extends StatefulWidget {
  final String title;
  final Future<Map<String, dynamic>> Function() loader;
  final String listKey;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _MemberDataDialog({
    required this.title,
    required this.loader,
    this.listKey = 'transactions',
    required this.itemBuilder,
  });

  @override
  State<_MemberDataDialog> createState() => _MemberDataDialogState();
}

class _MemberDataDialogState extends State<_MemberDataDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.loader();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat data';
        _loading = false;
      });
      return;
    }

    final listRaw = result[widget.listKey];
    final list = listRaw is List
        ? listRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 700,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator()))
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
                    ],
                  )
                : _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: Text('Tidak ada data')),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => widget.itemBuilder(_items[index]),
                        ),
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
      ],
    );
  }
}
