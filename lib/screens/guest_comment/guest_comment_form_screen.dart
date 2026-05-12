import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/guest_comment_service.dart';

/// Verifikasi / detail guest comment (sama alur dengan ERP Verify + Show).
class GuestCommentFormScreen extends StatefulWidget {
  final int formId;

  const GuestCommentFormScreen({super.key, required this.formId});

  @override
  State<GuestCommentFormScreen> createState() => _GuestCommentFormScreenState();
}

class _GuestCommentFormScreenState extends State<GuestCommentFormScreen> {
  final _service = GuestCommentService();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _form;
  List<dynamic> _ratingOptions = [];
  bool _canChooseOutlet = false;
  List<dynamic> _outlets = [];
  Map<String, dynamic>? _lockedOutlet;

  final _guestName = TextEditingController();
  final _guestPhone = TextEditingController();
  final _guestAddress = TextEditingController();
  final _visitDate = TextEditingController();
  final _praised = TextEditingController();
  final _praisedOutlet = TextEditingController();
  final _marketingSource = TextEditingController();
  final _comment = TextEditingController();
  final _capaKronologi = TextEditingController();
  final _capaCorrective = TextEditingController();
  final _capaPreventive = TextEditingController();

  String? _rs;
  String? _rf;
  String? _rb;
  String? _rc;
  String? _rst;
  String? _rv;
  int? _idOutlet;
  DateTime? _guestDob;
  bool _markVerified = false;
  bool _saving = false;
  bool _requiresCapa = false;
  String _issueSeverity = '';

  bool get _readOnly => (_form?['status']?.toString() == 'verified');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _guestName.dispose();
    _guestPhone.dispose();
    _guestAddress.dispose();
    _visitDate.dispose();
    _praised.dispose();
    _praisedOutlet.dispose();
    _marketingSource.dispose();
    _comment.dispose();
    _capaKronologi.dispose();
    _capaCorrective.dispose();
    _capaPreventive.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final meta = await _service.getMeta();
    final data = await _service.getForm(widget.formId);
    if (!mounted) return;
    if (data['success'] != true || data['form'] == null) {
      setState(() {
        _loading = false;
        _error = data['message']?.toString() ?? 'Gagal memuat data';
      });
      return;
    }
    if (meta['success'] == true) {
      _ratingOptions = meta['rating_options'] as List<dynamic>? ?? [];
      _canChooseOutlet = meta['can_choose_outlet'] == true;
      _outlets = meta['outlets'] as List<dynamic>? ?? [];
      _lockedOutlet = meta['locked_outlet'] as Map<String, dynamic>?;
    }
    _requiresCapa = data['requires_capa'] == true;
    _issueSeverity = (data['issue_severity']?.toString() ?? '').toLowerCase().trim();
    final existingCapa = data['existing_capa'];
    if (existingCapa is Map) {
      _capaKronologi.text = existingCapa['kronologi']?.toString() ?? '';
      _capaCorrective.text = existingCapa['corrective_action']?.toString() ?? '';
      _capaPreventive.text = existingCapa['preventive_action']?.toString() ?? '';
    }
    _applyForm(data['form'] as Map<String, dynamic>);
    setState(() => _loading = false);
  }

  void _applyForm(Map<String, dynamic> f) {
    _form = f;
    _guestName.text = f['guest_name']?.toString() ?? '';
    _guestPhone.text = f['guest_phone']?.toString() ?? '';
    _guestAddress.text = f['guest_address']?.toString() ?? '';
    _visitDate.text = f['visit_date']?.toString() ?? '';
    _praised.text = f['praised_staff_name']?.toString() ?? '';
    _praisedOutlet.text = f['praised_staff_outlet']?.toString() ?? '';
    _marketingSource.text = f['marketing_source']?.toString() ?? '';
    _comment.text = f['comment_text']?.toString() ?? '';
    _rs = f['rating_service']?.toString();
    _rf = f['rating_food']?.toString();
    _rb = f['rating_beverage']?.toString();
    _rc = f['rating_cleanliness']?.toString();
    _rst = f['rating_staff']?.toString();
    _rv = f['rating_value']?.toString();
    final oid = f['id_outlet'];
    _idOutlet = oid is int ? oid : (oid is num ? oid.toInt() : null);
    final gd = f['guest_dob'];
    if (gd != null && gd.toString().isNotEmpty) {
      try {
        _guestDob = DateTime.parse(gd.toString().split('T').first);
      } catch (_) {
        _guestDob = null;
      }
    } else {
      _guestDob = null;
    }
    _markVerified = false;
  }

  String _ratingUiLabel(String? code) {
    if (code == null || code.isEmpty) return '—';
    return code[0].toUpperCase() + code.substring(1);
  }

  Future<void> _pickDob() async {
    if (_readOnly) return;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _guestDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) setState(() => _guestDob = d);
  }

  bool get _capaIncomplete =>
      _requiresCapa &&
      (_capaKronologi.text.trim().isEmpty ||
          _capaCorrective.text.trim().isEmpty ||
          _capaPreventive.text.trim().isEmpty);

  String get _severityLabel {
    const map = {
      'critical': 'CRITICAL',
      'severe': 'CRITICAL',
      'major': 'MAJOR',
      'negative': 'MAJOR',
      'minor': 'MINOR',
      'mild_negative': 'MINOR',
    };
    return map[_issueSeverity] ?? _issueSeverity.toUpperCase();
  }

  Future<void> _save() async {
    if (_readOnly) return;
    if (_markVerified && _capaIncomplete) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              const Text('CAPA belum lengkap'),
            ],
          ),
          content: Text(
            'Severity $_severityLabel — Leader wajib mengisi Kronologi, Corrective Action, dan Preventive Action sebelum verifikasi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    _markVerified ? 'Menyimpan & memverifikasi…' : 'Menyimpan…',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final body = <String, dynamic>{
      'rating_service': _rs,
      'rating_food': _rf,
      'rating_beverage': _rb,
      'rating_cleanliness': _rc,
      'rating_staff': _rst,
      'rating_value': _rv,
      'comment_text': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      'guest_name': _guestName.text.trim().isEmpty ? null : _guestName.text.trim(),
      'guest_address':
          _guestAddress.text.trim().isEmpty ? null : _guestAddress.text.trim(),
      'guest_phone':
          _guestPhone.text.trim().isEmpty ? null : _guestPhone.text.trim(),
      'visit_date': _visitDate.text.trim().isEmpty ? null : _visitDate.text.trim(),
      'praised_staff_name':
          _praised.text.trim().isEmpty ? null : _praised.text.trim(),
      'praised_staff_outlet': _praisedOutlet.text.trim().isEmpty
          ? null
          : _praisedOutlet.text.trim(),
      'marketing_source': _marketingSource.text.trim().isEmpty
          ? null
          : _marketingSource.text.trim(),
      'mark_verified': _markVerified,
      if (_requiresCapa) ...{
        'capa_kronologi': _capaKronologi.text.trim(),
        'capa_corrective_action': _capaCorrective.text.trim(),
        'capa_preventive_action': _capaPreventive.text.trim(),
      },
    };
    if (_guestDob != null) {
      body['guest_dob'] = DateFormat('yyyy-MM-dd').format(_guestDob!);
    } else {
      body['guest_dob'] = null;
    }
    if (_canChooseOutlet) {
      body['id_outlet'] = _idOutlet;
    }

    Map<String, dynamic> res;
    try {
      res = await _service.updateForm(id: widget.formId, fields: body);
    } catch (e) {
      res = {'success': false, 'message': e.toString()};
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _saving = false);
      }
    }

    if (!mounted) return;

    if (res['success'] == true && res['form'] != null) {
      _applyForm(res['form'] as Map<String, dynamic>);
      setState(() {});
      final verifiedNow = _form?['status']?.toString() == 'verified';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Berhasil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                res['message']?.toString() ??
                    (verifiedNow
                        ? 'Data tersimpan dan terverifikasi.'
                        : 'Perubahan disimpan.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey.shade800),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size(120, 44),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (_readOnly) {
        Navigator.of(context).pop(true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menyimpan'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus guest comment?'),
        content: const Text('Data dan foto akan dihapus permanen.'),
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
    if (ok != true) return;
    final res = await _service.deleteForm(widget.formId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menghapus'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openImage(String? url) {
    if (url == null || url.isEmpty) return;
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

  Widget _ratingTile(String key, String label, String? value, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _readOnly
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_ratingUiLabel(value)),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: (value != null && value.isNotEmpty) ? value : null,
                  hint: const Text('Pilih'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('—'),
                    ),
                    ..._ratingOptions.map((o) {
                      final s = o.toString();
                      return DropdownMenuItem<String?>(
                        value: s,
                        child: Text(_ratingUiLabel(s)),
                      );
                    }),
                  ],
                  onChanged: onChanged,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_readOnly ? 'Detail #${widget.formId}' : 'Verifikasi #${widget.formId}'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
            ),
          ),
        ),
        actions: [
          if (!_readOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Hapus',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              elevation: 0,
                              child: InkWell(
                                onTap: () => _openImage(_form?['image_url']?.toString()),
                                borderRadius: BorderRadius.circular(20),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: AspectRatio(
                                    aspectRatio: 210 / 297,
                                    child: _form?['image_url'] != null
                                        ? CachedNetworkImage(
                                            imageUrl: _form!['image_url'].toString(),
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketuk gambar untuk perbesar',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            _metaCard(),
                            const SizedBox(height: 16),
                            Text(
                              'Rating',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _ratingTile('rs', 'Service', _rs, (v) => setState(() => _rs = v)),
                            _ratingTile('rf', 'Food', _rf, (v) => setState(() => _rf = v)),
                            _ratingTile('rb', 'Beverage', _rb, (v) => setState(() => _rb = v)),
                            _ratingTile('rc', 'Cleanliness', _rc, (v) => setState(() => _rc = v)),
                            _ratingTile('rst', 'Staff', _rst, (v) => setState(() => _rst = v)),
                            _ratingTile('rv', 'Value', _rv, (v) => setState(() => _rv = v)),
                            const SizedBox(height: 8),
                            _field(_comment, 'Komentar', maxLines: 4),
                            _field(_guestName, 'Nama tamu'),
                            _field(_guestPhone, 'Telepon'),
                            _field(_guestAddress, 'Alamat'),
                            _dobRow(),
                            _field(_visitDate, 'Tanggal kunjungan (teks bebas)'),
                            _field(_praised, 'Staff yang dipuji'),
                            _field(
                              _praisedOutlet,
                              'Outlet tertulis di form (Justus dsb.)',
                            ),
                            _field(
                              _marketingSource,
                              'Sumber marketing',
                              hintText:
                                  'Contoh: Sosial Media · atau Lainnya: teman kantor',
                            ),
                            if (_canChooseOutlet) _outletDropdown(),
                            if (!_canChooseOutlet && _lockedOutlet != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Outlet',
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _lockedOutlet!['nama_outlet']?.toString() ?? '—',
                                  ),
                                ),
                              ),
                            if (_requiresCapa) ...[
                              const SizedBox(height: 16),
                              _buildCapaSection(),
                            ],
                            if (!_readOnly) ...[
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                value: _markVerified,
                                onChanged: (v) =>
                                    setState(() => _markVerified = v ?? false),
                                title: const Text('Tandai terverifikasi setelah simpan'),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!_readOnly)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildCapaSection() {
    const sevColors = {
      'critical': (Color(0xFFFEF2F2), Color(0xFFFCA5A5), Color(0xFF991B1B), Color(0xFFDC2626)),
      'severe': (Color(0xFFFEF2F2), Color(0xFFFCA5A5), Color(0xFF991B1B), Color(0xFFDC2626)),
      'major': (Color(0xFFFFF7ED), Color(0xFFFDBA74), Color(0xFF9A3412), Color(0xFFEA580C)),
      'negative': (Color(0xFFFFF7ED), Color(0xFFFDBA74), Color(0xFF9A3412), Color(0xFFEA580C)),
      'minor': (Color(0xFFFEFCE8), Color(0xFFFDE047), Color(0xFF854D0E), Color(0xFFCA8A04)),
      'mild_negative': (Color(0xFFFEFCE8), Color(0xFFFDE047), Color(0xFF854D0E), Color(0xFFCA8A04)),
    };
    final colors = sevColors[_issueSeverity];
    final bg = colors?.$1 ?? const Color(0xFFFEF2F2);
    final border = colors?.$2 ?? const Color(0xFFFCA5A5);
    final textColor = colors?.$3 ?? const Color(0xFF991B1B);
    final iconColor = colors?.$4 ?? const Color(0xFFDC2626);

    if (_readOnly) {
      final hasData = _capaKronologi.text.trim().isNotEmpty ||
          _capaCorrective.text.trim().isNotEmpty ||
          _capaPreventive.text.trim().isNotEmpty;
      if (!hasData) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'CAPA (Telah diisi)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _capaReadOnlyField('Kronologi', _capaKronologi.text),
            const SizedBox(height: 8),
            _capaReadOnlyField('Corrective Action', _capaCorrective.text),
            const SizedBox(height: 8),
            _capaReadOnlyField('Preventive Action', _capaPreventive.text),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: border.withValues(alpha: 0.25),
                ),
                child: Icon(Icons.warning_amber_rounded, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Severity: $_severityLabel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leader wajib mengisi CAPA (Corrective & Preventive Action) sebelum data ini bisa diverifikasi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _capaTextField(_capaKronologi, 'Kronologi kejadian *',
              'Jelaskan kronologi kejadian yang menyebabkan keluhan tamu…', textColor),
          const SizedBox(height: 12),
          _capaTextField(_capaCorrective, 'Corrective Action *',
              'Tindakan perbaikan segera yang dilakukan…', textColor),
          const SizedBox(height: 12),
          _capaTextField(_capaPreventive, 'Preventive Action *',
              'Langkah pencegahan agar kejadian tidak terulang…', textColor),
        ],
      ),
    );
  }

  Widget _capaTextField(TextEditingController c, String label, String hint, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _capaReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.trim().isNotEmpty ? value : '—',
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.3),
        ),
      ],
    );
  }

  Widget _metaCard() {
    final c = _form?['creator'] as Map<String, dynamic>?;
    final v = _form?['verifier'] as Map<String, dynamic>?;
    final created = _form?['created_at']?.toString();
    final verified = _form?['verified_at']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusChip(_form?['status']?.toString()),
          const SizedBox(height: 10),
          Text('Pencatat: ${c?['nama_lengkap'] ?? '—'}', style: const TextStyle(fontSize: 13)),
          if (created != null)
            Text('Dibuat: $created', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (_form?['status'] == 'verified') ...[
            const SizedBox(height: 8),
            Text('Verifikasi: ${v?['nama_lengkap'] ?? '—'}', style: const TextStyle(fontSize: 13)),
            if (verified != null)
              Text(verified, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String? s) {
    final verified = s == 'verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        verified ? 'Terverifikasi' : 'Menunggu verifikasi',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: verified ? const Color(0xFF065F46) : const Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        readOnly: _readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dobRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Tanggal lahir tamu',
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _guestDob == null
                    ? '—'
                    : DateFormat.yMMMd('id_ID').format(_guestDob!),
              ),
            ),
            if (!_readOnly)
              TextButton(onPressed: _pickDob, child: const Text('Pilih')),
          ],
        ),
      ),
    );
  }

  Widget _outletDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Outlet',
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _readOnly
            ? Text(_form?['outlet']?['nama_outlet']?.toString() ?? '—')
            : DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _idOutlet,
                  hint: const Text('Pilih outlet'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('—')),
                    ..._outlets.map((o) {
                      final m = o as Map<String, dynamic>;
                      final id = m['id_outlet'];
                      final ii = id is int ? id : (id as num).toInt();
                      return DropdownMenuItem<int?>(
                        value: ii,
                        child: Text(m['nama_outlet']?.toString() ?? ''),
                      );
                    }),
                  ],
                  onChanged: (x) => setState(() => _idOutlet = x),
                ),
              ),
      ),
    );
  }
}
