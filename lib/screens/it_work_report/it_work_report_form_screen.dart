import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/it_work_report_service.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_scaffold.dart';
import 'it_work_report_media.dart';
import 'it_work_report_show_screen.dart';
import 'it_work_report_ui.dart';

class _ItemState {
  int? id;
  String deviceType;
  final TextEditingController labelCtrl;
  final TextEditingController identifierCtrl;
  final TextEditingController laptopUserCtrl;
  final TextEditingController notesCtrl;
  String result;
  List<String> scopes;
  final List<File> evidenceFiles;
  final List<Map<String, dynamic>> evidenceMetas;

  _ItemState({
    this.id,
    this.deviceType = 'pc',
    String label = '',
    String identifier = '',
    String laptopUser = '',
    String notes = '',
    this.result = '',
    List<String>? scopes,
    List<File>? evidenceFiles,
    List<Map<String, dynamic>>? evidenceMetas,
  })  : labelCtrl = TextEditingController(text: label),
        identifierCtrl = TextEditingController(text: identifier),
        laptopUserCtrl = TextEditingController(text: laptopUser),
        notesCtrl = TextEditingController(text: notes),
        scopes = scopes ?? [],
        evidenceFiles = evidenceFiles ?? [],
        evidenceMetas = evidenceMetas ?? [];

  void dispose() {
    labelCtrl.dispose();
    identifierCtrl.dispose();
    laptopUserCtrl.dispose();
    notesCtrl.dispose();
  }

  Map<String, dynamic> toPayload() {
    return {
      if (id != null) 'id': id,
      'device_type': deviceType,
      'device_label': labelCtrl.text.trim(),
      'identifier': identifierCtrl.text.trim(),
      if (deviceType == 'laptop') 'laptop_user_name': laptopUserCtrl.text.trim(),
      'scopes': List<String>.from(scopes),
      'notes': notesCtrl.text.trim(),
      'result': result,
    };
  }
}

class ItWorkReportFormScreen extends StatefulWidget {
  final int? reportId;
  final int? prefillTicketId;
  final String? prefillTicketNumber;
  final String? prefillTicketTitle;
  final int? prefillOutletId;

  const ItWorkReportFormScreen({
    super.key,
    this.reportId,
    this.prefillTicketId,
    this.prefillTicketNumber,
    this.prefillTicketTitle,
    this.prefillOutletId,
  });

  @override
  State<ItWorkReportFormScreen> createState() => _ItWorkReportFormScreenState();
}

class _ItWorkReportFormScreenState extends State<ItWorkReportFormScreen> {
  final _service = ItWorkReportService();
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _ticketSearchCtrl = TextEditingController();
  final _waContactCtrl = TextEditingController();
  final _waPhoneCtrl = TextEditingController();
  final _waTimeCtrl = TextEditingController();
  final _waSummaryCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _locationBusy = false;
  int? _capturingIndex;
  String? _error;

  String _workDate = '';
  String? _startHour;
  String? _startMinute;
  String? _endHour;
  String? _endMinute;
  int? _outletId;
  int? _executorId;
  String _sourceType = 'proactive';

  int? _ticketId;
  String _selectedTicketLabel = '';
  List<Map<String, dynamic>> _ticketResults = [];
  String _ticketSearchHint = '';
  Timer? _ticketTimer;

  String? _waReportDate;
  final List<File> _waScreenshots = [];
  final List<int> _removeEvidenceIds = [];
  final List<Map<String, dynamic>> _existingEvidences = [];

  List<_ItemState> _items = [];

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _executors = [];
  Map<String, String> _deviceTypes = {};
  Map<String, String> _scopeOptions = {};
  Map<String, String> _resultOptions = {};
  Map<String, String> _sourceOptions = {};
  int? _currentUserId;

  static final _hourOptions = List.generate(24, (i) => i.toString().padLeft(2, '0'));
  static final _minuteOptions = List.generate(60, (i) => i.toString().padLeft(2, '0'));

  bool get _isEdit => widget.reportId != null;

  List<Map<String, dynamic>> get _existingWa => _existingEvidences
      .where((e) =>
          e['kind']?.toString() == 'wa_screenshot' &&
          !_removeEvidenceIds.contains(_parseInt(e['id'])))
      .toList();

  List<Map<String, dynamic>> _existingItemEvidences(int? itemId) {
    if (itemId == null) return [];
    return _existingEvidences
        .where((e) =>
            _parseInt(e['it_work_report_item_id']) == itemId &&
            e['kind']?.toString() == 'work' &&
            !_removeEvidenceIds.contains(_parseInt(e['id'])))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _workDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _items = [_ItemState()];
    if (widget.prefillTicketId != null) {
      _sourceType = 'ticket';
      _ticketId = widget.prefillTicketId;
      final num = widget.prefillTicketNumber ?? '';
      final title = widget.prefillTicketTitle ?? '';
      _selectedTicketLabel = [num, title].where((e) => e.isNotEmpty).join(' — ');
      _outletId = widget.prefillOutletId;
    }
    _load();
  }

  @override
  void dispose() {
    _ticketTimer?.cancel();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _ticketSearchCtrl.dispose();
    _waContactCtrl.dispose();
    _waPhoneCtrl.dispose();
    _waTimeCtrl.dispose();
    _waSummaryCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');

  ({String hour, String minute}) _splitHm(dynamic value) {
    final s = value?.toString() ?? '';
    final sliced = s.length >= 5 ? s.substring(0, 5) : s;
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(sliced);
    if (m == null) return (hour: '', minute: '');
    return (hour: m.group(1)!, minute: m.group(2)!);
  }

  ({String date, String time}) _splitDateTimeLocal(dynamic value) {
    if (value == null) return (date: '', time: '');
    var s = value.toString().replaceFirst(' ', 'T');
    if (s.length >= 16) s = s.substring(0, 16);
    final parts = s.split('T');
    if (parts.isEmpty) return (date: '', time: '');
    return (
      date: parts[0],
      time: parts.length > 1 ? parts[1].substring(0, parts[1].length.clamp(0, 5)) : '',
    );
  }

  String get _startTime {
    if (_startHour == null ||
        _startHour!.isEmpty ||
        _startMinute == null ||
        _startMinute!.isEmpty) {
      return '';
    }
    return '$_startHour:$_startMinute';
  }

  String get _endTime {
    if (_endHour == null || _endHour!.isEmpty || _endMinute == null || _endMinute!.isEmpty) {
      return '';
    }
    return '$_endHour:$_endMinute';
  }

  void _normalizeWaTime() {
    var v = _waTimeCtrl.text.trim().replaceAll('.', ':');
    if (RegExp(r'^\d{3,4}$').hasMatch(v)) {
      v = v.padLeft(4, '0');
      v = '${v.substring(0, 2)}:${v.substring(2)}';
    }
    if (RegExp(r'^\d{1,2}:\d{1,2}$').hasMatch(v)) {
      final parts = v.split(':');
      final hh = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
      final mm = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
      _waTimeCtrl.text = '${_pad2(hh)}:${_pad2(mm)}';
    } else if (v.isNotEmpty && !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)) {
      _waTimeCtrl.text = '';
    }
  }

  String get _waReportedAt {
    final date = _waReportDate ?? '';
    final time = _waTimeCtrl.text.trim();
    if (date.isEmpty) return '';
    if (time.isNotEmpty) return '$date $time:00';
    return '$date 00:00:00';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final createRes = await _service.getCreateData();
    if (!mounted) return;

    if (createRes['success'] != true) {
      setState(() {
        _loading = false;
        _error = createRes['message']?.toString() ?? 'Gagal memuat data form';
      });
      return;
    }

    final data = createRes['data'] is Map
        ? Map<String, dynamic>.from(createRes['data'] as Map)
        : createRes;
    _outlets = _asMapList(data['outlets']);
    _executors = _asMapList(data['executors']);
    _deviceTypes = _asStringMap(data['deviceTypes']);
    _scopeOptions = _asStringMap(data['scopeOptions']);
    _resultOptions = _asStringMap(data['resultOptions']);
    _sourceOptions = _asStringMap(data['sourceOptions']);
    if (_sourceOptions.isEmpty) {
      _sourceOptions = {
        'proactive': 'Proaktif',
        'ticket': 'Ticket',
        'whatsapp': 'WhatsApp',
      };
    }
    if (_deviceTypes.isEmpty) {
      _deviceTypes = {
        'pc': 'PC',
        'laptop': 'Laptop',
        'printer': 'Printer',
        'scanner': 'Scanner',
        'switch_ap': 'Switch / AP',
        'nvr_cctv': 'NVR / CCTV',
        'other': 'Lainnya',
      };
    }
    if (_scopeOptions.isEmpty) {
      _scopeOptions = {
        'cleaning_hardware': 'Cleaning hardware',
        'os_software_check': 'Cek OS dan software',
        'network': 'Jaringan',
        'cctv': 'CCTV',
        'peripheral': 'Peripheral (printer/scanner)',
        'security_update': 'Update / patch keamanan',
        'other': 'Lainnya',
      };
    }
    if (_resultOptions.isEmpty) {
      _resultOptions = {
        'ok': 'OK',
        'issue_found': 'Issue found',
        'needs_followup': 'Needs follow-up',
      };
    }

    _currentUserId = _parseInt(data['currentUserId']);
    if (_executorId == null) {
      _executorId = _currentUserId;
    }
    if (_currentUserId == null) {
      final user = await AuthService().getUserData();
      _currentUserId = _parseInt(user?['id']);
      _executorId ??= _currentUserId;
    }

    if (widget.reportId != null) {
      final showRes = await _service.getReport(widget.reportId!);
      if (!mounted) return;
      if (showRes['success'] != true) {
        setState(() {
          _loading = false;
          _error = showRes['message']?.toString() ?? 'Gagal memuat report';
        });
        return;
      }
      final report = showRes['data'] is Map
          ? Map<String, dynamic>.from(showRes['data'] as Map)
          : <String, dynamic>{};
      _hydrateFromReport(report);
    }

    setState(() => _loading = false);
  }

  void _hydrateFromReport(Map<String, dynamic> report) {
    final wd = report['work_date']?.toString() ?? '';
    if (wd.length >= 10) _workDate = wd.substring(0, 10);

    final startHm = _splitHm(report['start_time']);
    _startHour = startHm.hour.isEmpty ? null : startHm.hour;
    _startMinute = startHm.minute.isEmpty ? null : startHm.minute;
    final endHm = _splitHm(report['end_time']);
    _endHour = endHm.hour.isEmpty ? null : endHm.hour;
    _endMinute = endHm.minute.isEmpty ? null : endHm.minute;

    _outletId = _parseInt(report['outlet_id']) ?? _outletId;
    _executorId = _parseInt(report['executor_id']) ?? _executorId;
    _sourceType = report['source_type']?.toString() ?? _sourceType;
    _ticketId = _parseInt(report['ticket_id']);
    final ticket = report['ticket'];
    if (ticket is Map) {
      final tn = ticket['ticket_number']?.toString() ?? '';
      final tt = ticket['title']?.toString() ?? '';
      _selectedTicketLabel = [tn, tt].where((e) => e.isNotEmpty).join(' — ');
    }

    _waContactCtrl.text = report['wa_contact_name']?.toString() ?? '';
    _waPhoneCtrl.text = report['wa_phone']?.toString() ?? '';
    _waSummaryCtrl.text = report['wa_summary']?.toString() ?? '';
    final waDt = _splitDateTimeLocal(report['wa_reported_at']);
    _waReportDate = waDt.date.isEmpty ? null : waDt.date;
    _waTimeCtrl.text = waDt.time;

    _titleCtrl.text = report['title']?.toString() ?? '';
    _notesCtrl.text = report['notes']?.toString() ?? '';

    final map = <int, Map<String, dynamic>>{};
    for (final e in _asMapList(report['evidences'])) {
      final id = _parseInt(e['id']);
      if (id != null) map[id] = e;
    }
    for (final item in _asMapList(report['items'])) {
      for (final e in _asMapList(item['evidences'])) {
        final id = _parseInt(e['id']);
        if (id != null) map[id] = e;
      }
    }
    _existingEvidences
      ..clear()
      ..addAll(map.values);

    final itemsRaw = _asMapList(report['items']);
    for (final item in _items) {
      item.dispose();
    }
    if (itemsRaw.isEmpty) {
      _items = [_ItemState()];
    } else {
      _items = itemsRaw.map((i) {
        final scopesRaw = i['scopes'];
        final scopes = scopesRaw is List
            ? scopesRaw.map((e) => e.toString()).toList()
            : <String>[];
        return _ItemState(
          id: _parseInt(i['id']),
          deviceType: i['device_type']?.toString() ?? 'pc',
          label: i['device_label']?.toString() ?? '',
          identifier: i['identifier']?.toString() ?? '',
          laptopUser: i['laptop_user_name']?.toString() ?? '',
          notes: i['notes']?.toString() ?? '',
          result: i['result']?.toString() ?? '',
          scopes: scopes,
        );
      }).toList();
    }
  }

  Future<void> _pickWorkDate() async {
    DateTime initial = DateTime.now();
    if (_workDate.length >= 10) {
      try {
        initial = DateTime.parse(_workDate);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _workDate =
          '${picked.year}-${_pad2(picked.month)}-${_pad2(picked.day)}';
    });
  }

  Future<void> _pickWaDate() async {
    DateTime initial = DateTime.now();
    if (_waReportDate != null && _waReportDate!.length >= 10) {
      try {
        initial = DateTime.parse(_waReportDate!);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _waReportDate =
          '${picked.year}-${_pad2(picked.month)}-${_pad2(picked.day)}';
    });
  }

  void _onTicketSearch([String? query]) {
    _ticketTimer?.cancel();
    _ticketTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_executorId == null) {
        if (mounted) {
          setState(() {
            _ticketResults = [];
            _ticketSearchHint = 'Pilih pelaksana terlebih dahulu.';
          });
        }
        return;
      }
      final q = (query ?? _ticketSearchCtrl.text).trim();
      final res = await _service.searchTickets(
        q: q,
        outletId: _outletId,
        executorId: _executorId,
      );
      if (!mounted) return;
      final list = _asMapList(res['data']);
      setState(() {
        _ticketResults = list;
        _ticketSearchHint = list.isEmpty
            ? 'Tidak ada ticket aktif yang di-assign ke pelaksana ini.'
            : '';
      });
    });
  }

  void _selectTicket(Map<String, dynamic> t) {
    setState(() {
      _ticketId = _parseInt(t['id']);
      _selectedTicketLabel =
          t['label']?.toString() ??
          '${t['ticket_number'] ?? ''} — ${t['title'] ?? ''}';
      final oid = _parseInt(t['outlet_id']);
      if (oid != null && _outletId == null) _outletId = oid;
      _ticketResults = [];
      _ticketSearchHint = '';
      _ticketSearchCtrl.clear();
    });
  }

  void _addItem() {
    setState(() => _items.add(_ItemState()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickWaScreenshots() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    setState(() {
      for (final f in files) {
        _waScreenshots.add(File(f.path));
      }
    });
  }

  void _removeWaNew(int index) {
    setState(() => _waScreenshots.removeAt(index));
  }

  void _markRemoveEvidence(int id) {
    setState(() {
      if (!_removeEvidenceIds.contains(id)) _removeEvidenceIds.add(id);
    });
  }

  Future<Map<String, dynamic>> _resolveLocationTag() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izinkan akses lokasi');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final latitude = pos.latitude;
    final longitude = pos.longitude;
    final mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';

    String address = '';
    try {
      final geo = await _service.reverseGeocode(lat: latitude, lng: longitude);
      address = geo['address']?.toString() ?? geo['data']?['address']?.toString() ?? '';
    } catch (_) {
      address = '';
    }
    if (address.isEmpty) {
      address = 'Lokasi GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    }

    final now = DateTime.now();
    return {
      'date': '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}',
      'time': '${_pad2(now.hour)}:${_pad2(now.minute)}:${_pad2(now.second)}',
      'captured_at': now.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'maps_url': mapsUrl,
    };
  }

  Future<void> _captureItemEvidence(int index) async {
    setState(() {
      _locationBusy = true;
      _capturingIndex = index;
    });

    Map<String, dynamic>? meta;
    try {
      meta = await _resolveLocationTag();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationBusy = false;
        _capturingIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi GPS wajib aktif untuk mengambil evidence. Izinkan akses lokasi lalu coba lagi.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _locationBusy = false;
      _capturingIndex = null;
    });

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _locationBusy = true;
      _capturingIndex = index;
    });

    try {
      final stamped = await stampPhotoWithTag(File(picked.path), meta);
      if (!mounted) return;
      setState(() {
        _items[index].evidenceFiles.add(stamped);
        _items[index].evidenceMetas.add(Map<String, dynamic>.from(meta!));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _capturingIndex = null;
        });
      }
    }
  }

  void _removeItemNewEvidence(int itemIndex, int pIdx) {
    setState(() {
      _items[itemIndex].evidenceFiles.removeAt(pIdx);
      _items[itemIndex].evidenceMetas.removeAt(pIdx);
    });
  }

  String? _validate({required bool submit}) {
    if (_workDate.isEmpty) return 'Tanggal kerja wajib diisi.';
    if (_outletId == null) return 'Outlet wajib dipilih.';
    if (_sourceType.isEmpty) return 'Sumber wajib dipilih.';

    if (_sourceType == 'ticket' && _ticketId == null) {
      return 'Ticket wajib dipilih.';
    }

    if (_items.isEmpty) return 'Minimal 1 perangkat.';

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.labelCtrl.text.trim().isEmpty) {
        return 'Perangkat #${i + 1}: label / lokasi wajib diisi.';
      }
      if (item.scopes.isEmpty) {
        return 'Perangkat #${i + 1}: pilih minimal 1 scope pekerjaan.';
      }
      if (item.deviceType == 'laptop') {
        if (item.laptopUserCtrl.text.trim().isEmpty) {
          return 'Perangkat #${i + 1}: nama pengguna laptop wajib diisi.';
        }
        if (item.identifierCtrl.text.trim().isEmpty) {
          return 'Perangkat #${i + 1}: serial laptop wajib diisi.';
        }
      }
      if (!submit) continue;
      final newCount = item.evidenceFiles.length;
      final oldCount = _existingItemEvidences(item.id).length;
      if (newCount + oldCount < 1) {
        return 'Perangkat #${i + 1}: ambil minimal 1 evidence dari kamera.';
      }
    }

    if (submit && _sourceType == 'whatsapp') {
      if (_waContactCtrl.text.trim().isEmpty) {
        return 'Nama kontak WhatsApp wajib diisi.';
      }
      if (_waSummaryCtrl.text.trim().isEmpty) {
        return 'Ringkasan chat WhatsApp wajib diisi.';
      }
      if (_waScreenshots.isEmpty && _existingWa.isEmpty) {
        return 'Screenshot WhatsApp wajib diupload.';
      }
    }

    return null;
  }

  Future<void> _save({required bool submit}) async {
    _normalizeWaTime();
    final err = _validate(submit: submit);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _saving = true);

    final fields = <String, String>{
      'work_date': _workDate,
      if (_startTime.isNotEmpty) 'start_time': _startTime,
      if (_endTime.isNotEmpty) 'end_time': _endTime,
      'outlet_id': '$_outletId',
      if (_executorId != null) 'executor_id': '$_executorId',
      'source_type': _sourceType,
      if (_ticketId != null && _sourceType == 'ticket') 'ticket_id': '$_ticketId',
      if (_sourceType == 'whatsapp') ...{
        'wa_contact_name': _waContactCtrl.text.trim(),
        'wa_phone': _waPhoneCtrl.text.trim(),
        if (_waReportedAt.isNotEmpty) 'wa_reported_at': _waReportedAt,
        'wa_summary': _waSummaryCtrl.text.trim(),
      },
      'title': _titleCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
    };

    final items = _items.map((e) => e.toPayload()).toList();
    final itemFiles = _items.map((e) => List<File>.from(e.evidenceFiles)).toList();
    final itemMetas = _items
        .map((e) => e.evidenceMetas
            .map((m) => <String, dynamic>{
                  'latitude': m['latitude'],
                  'longitude': m['longitude'],
                  'address': m['address'],
                  'maps_url': m['maps_url'],
                  'captured_at': m['captured_at'],
                })
            .toList())
        .toList();

    final res = await _service.saveReport(
      id: widget.reportId,
      fields: fields,
      items: items,
      waScreenshots: List<File>.from(_waScreenshots),
      itemEvidenceFiles: itemFiles,
      itemEvidenceMetas: itemMetas,
      removeEvidenceIds: List<int>.from(_removeEvidenceIds),
      submit: submit,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      final data = res['data'];
      final id = data is Map ? _parseInt(data['id']) : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil disimpan')),
      );
      if (id != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ItWorkReportShowScreen(reportId: id),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } else {
      String msg = res['message']?.toString() ?? 'Gagal menyimpan';
      final errors = res['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          msg = first.first.toString();
        } else if (first != null) {
          msg = first.toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: ItWorkReportUi.primary, width: 1.5),
      ),
    );
  }

  Widget _sectionCard({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: ItWorkReportUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: ItWorkReportUi.textMuted)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _hmDropdowns({
    required String? hour,
    required String? minute,
    required ValueChanged<String?> onHour,
    required ValueChanged<String?> onMinute,
  }) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: hour?.isEmpty == true ? null : hour,
            decoration: _dec('Jam'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-')),
              ..._hourOptions.map((h) => DropdownMenuItem(value: h, child: Text(h))),
            ],
            onChanged: onHour,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: minute?.isEmpty == true ? null : minute,
            decoration: _dec('Menit'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-')),
              ..._minuteOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))),
            ],
            onChanged: onMinute,
          ),
        ),
      ],
    );
  }

  Widget _thumb({
    required String url,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    String? caption,
  }) {
    final resolved = itWorkResolveUrl(url);
    final isLocal = itWorkIsLocalPath(url) || (!itWorkIsNetworkUrl(resolved) && resolved.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          border: Border.all(color: ItWorkReportUi.border),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF1F5F9),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 80,
                  child: isLocal
                      ? Image.file(
                          File(itWorkLocalPath(resolved)),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        )
                      : Image.network(
                          resolved,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
                if (caption != null && caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: ItWorkReportUi.textMuted),
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitSection() {
    return _sectionCard(
      title: 'Informasi Kunjungan',
      children: [
        InkWell(
          onTap: _pickWorkDate,
          child: InputDecorator(
            decoration: _dec('Tanggal kerja *'),
            child: Text(
              _workDate.isEmpty
                  ? 'Pilih tanggal'
                  : DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(_workDate)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Jam mulai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _hmDropdowns(
          hour: _startHour,
          minute: _startMinute,
          onHour: (v) => setState(() => _startHour = v),
          onMinute: (v) => setState(() => _startMinute = v),
        ),
        const SizedBox(height: 4),
        const Text('Format 24 jam', style: TextStyle(fontSize: 10, color: ItWorkReportUi.textMuted)),
        const SizedBox(height: 12),
        const Text('Jam selesai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _hmDropdowns(
          hour: _endHour,
          minute: _endMinute,
          onHour: (v) => setState(() => _endHour = v),
          onMinute: (v) => setState(() => _endMinute = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _outletId,
          decoration: _dec('Outlet *'),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Pilih outlet')),
            ..._outlets.map((o) {
              final id = ItWorkReportUi.outletId(o);
              return DropdownMenuItem(
                value: id,
                child: Text(ItWorkReportUi.outletName(o), overflow: TextOverflow.ellipsis),
              );
            }),
          ],
          onChanged: (v) {
            setState(() => _outletId = v);
            if (_sourceType == 'ticket') _onTicketSearch();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _executors.any((u) => ItWorkReportUi.userId(u) == _executorId)
              ? _executorId
              : null,
          decoration: _dec('Pelaksana'),
          isExpanded: true,
          items: _executors.map((u) {
            final id = ItWorkReportUi.userId(u);
            return DropdownMenuItem(
              value: id,
              child: Text(ItWorkReportUi.userName(u), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _executorId = v;
              if (_sourceType == 'ticket') {
                _ticketId = null;
                _selectedTicketLabel = '';
                _ticketSearchCtrl.clear();
                _ticketResults = [];
              }
            });
            if (_sourceType == 'ticket') _onTicketSearch();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sourceType,
          decoration: _dec('Sumber *'),
          items: _sourceOptions.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _sourceType = v;
              if (v != 'ticket') {
                _ticketId = null;
                _selectedTicketLabel = '';
                _ticketResults = [];
                _ticketSearchHint = '';
              }
            });
            if (v == 'ticket') _onTicketSearch();
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: _titleCtrl, decoration: _dec('Judul / ringkasan', hint: 'Opsional')),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: _dec('Catatan umum'),
        ),
      ],
    );
  }

  Widget _buildTicketSection() {
    return _sectionCard(
      title: 'Link Ticket',
      children: [
        TextField(
          controller: _ticketSearchCtrl,
          decoration: _dec('Cari ticket', hint: 'Nomor atau judul ticket...'),
          onChanged: _onTicketSearch,
          onTap: () => _onTicketSearch(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Hanya ticket assign ke pelaksana (open / in progress / pending)',
          style: TextStyle(fontSize: 11, color: ItWorkReportUi.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          'Terpilih: ${_selectedTicketLabel.isEmpty ? 'Belum dipilih' : _selectedTicketLabel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (_ticketResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: ItWorkReportUi.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _ticketResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = _ticketResults[i];
                final statusName = t['status_name']?.toString();
                return ListTile(
                  dense: true,
                  title: Text(
                    '${t['ticket_number'] ?? ''} — ${t['title'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: (t['outlet_name']?.toString().isNotEmpty ?? false)
                      ? Text(t['outlet_name'].toString(), style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: (statusName != null && statusName.isNotEmpty)
                      ? Text(
                          statusName,
                          style: const TextStyle(fontSize: 10, color: ItWorkReportUi.textMuted),
                        )
                      : null,
                  onTap: () => _selectTicket(t),
                );
              },
            ),
          ),
        ] else if (_ticketSearchHint.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _ticketSearchHint,
            style: const TextStyle(fontSize: 12, color: ItWorkReportUi.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _buildWaSection() {
    final lightboxUrls = [
      ..._waScreenshots.map((f) => f.path),
      ..._existingWa
          .where((e) => e['is_image'] == true || (e['url']?.toString().isNotEmpty ?? false))
          .map((e) => e['url']?.toString() ?? ''),
    ].where((u) => u.isNotEmpty).toList();

    return _sectionCard(
      title: 'Sumber WhatsApp',
      children: [
        TextField(controller: _waContactCtrl, decoration: _dec('Nama kontak *')),
        const SizedBox(height: 12),
        TextField(controller: _waPhoneCtrl, decoration: _dec('No. HP'), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickWaDate,
                child: InputDecorator(
                  decoration: _dec('Tanggal lapor'),
                  child: Text(_waReportDate ?? 'Pilih tanggal'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _waTimeCtrl,
                decoration: _dec('Jam (HH:mm)'),
                keyboardType: TextInputType.number,
                maxLength: 5,
                onEditingComplete: () {
                  setState(_normalizeWaTime);
                },
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
              ),
            ),
          ],
        ),
        const Text('Jam format 24 jam', style: TextStyle(fontSize: 10, color: ItWorkReportUi.textMuted)),
        const SizedBox(height: 12),
        TextField(
          controller: _waSummaryCtrl,
          maxLines: 2,
          decoration: _dec('Ringkasan chat *'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Screenshot WA (upload file, wajib saat submit)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickWaScreenshots,
          icon: const Icon(Icons.upload_file, color: ItWorkReportUi.primary),
          label: const Text('Upload screenshot'),
          style: OutlinedButton.styleFrom(foregroundColor: ItWorkReportUi.primary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...List.generate(_waScreenshots.length, (i) {
              final path = _waScreenshots[i].path;
              final idx = lightboxUrls.indexOf(path);
              return _thumb(
                url: path,
                onTap: () => openItWorkLightbox(context, lightboxUrls, idx < 0 ? 0 : idx),
                onRemove: () => _removeWaNew(i),
              );
            }),
            ...List.generate(_existingWa.length, (i) {
              final ev = _existingWa[i];
              final url = ev['url']?.toString() ?? '';
              final idx = lightboxUrls.indexOf(url);
              final id = _parseInt(ev['id']);
              return _thumb(
                url: url,
                onTap: () => openItWorkLightbox(context, lightboxUrls, idx < 0 ? 0 : idx),
                onRemove: () {
                  if (id != null) _markRemoveEvidence(id);
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildItemCard(int index, _ItemState item) {
    final existing = _existingItemEvidences(item.id);
    final lightboxUrls = [
      ...item.evidenceFiles.map((f) => f.path),
      ...existing.map((e) => e['url']?.toString() ?? ''),
    ].where((u) => u.isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: ItWorkReportUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFCFFAFE),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ItWorkReportUi.primaryDark,
                  ),
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                TextButton.icon(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: item.deviceType,
            decoration: _dec('Tipe *'),
            items: _deviceTypes.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => item.deviceType = v);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.labelCtrl,
            decoration: _dec('Label / lokasi *', hint: 'PC Kasir 1'),
          ),
          if (item.deviceType != 'laptop') ...[
            const SizedBox(height: 10),
            TextField(
              controller: item.identifierCtrl,
              decoration: _dec('Identifier', hint: 'IP / hostname / serial'),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: item.result.isEmpty ? null : item.result,
            decoration: _dec('Hasil'),
            items: [
              const DropdownMenuItem(value: null, child: Text('-')),
              ..._resultOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => item.result = v ?? ''),
          ),
          if (item.deviceType == 'laptop') ...[
            const SizedBox(height: 10),
            TextField(
              controller: item.laptopUserCtrl,
              decoration: _dec('Nama pengguna laptop *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.identifierCtrl,
              decoration: _dec('Serial laptop *'),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Scope pekerjaan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _scopeOptions.entries.map((e) {
              final selected = item.scopes.contains(e.key);
              return FilterChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFFCFFAFE),
                checkmarkColor: ItWorkReportUi.primaryDark,
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      item.scopes.add(e.key);
                    } else {
                      item.scopes.remove(e.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.notesCtrl,
            maxLines: 3,
            decoration: _dec('Catatan perangkat', hint: 'Catatan detail pekerjaan...'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Evidence perangkat (wajib dari kamera + tag lokasi saat submit)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _locationBusy ? null : () => _captureItemEvidence(index),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(
              _locationBusy && _capturingIndex == index
                  ? 'Mengambil lokasi...'
                  : 'Ambil dari kamera',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload galeri tidak diizinkan. Foto otomatis ditandai tanggal, jam, alamat & koordinat.',
            style: TextStyle(fontSize: 11, color: ItWorkReportUi.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(item.evidenceFiles.length, (pIdx) {
                final path = item.evidenceFiles[pIdx].path;
                final idx = lightboxUrls.indexOf(path);
                final meta = pIdx < item.evidenceMetas.length ? item.evidenceMetas[pIdx] : null;
                return _thumb(
                  url: path,
                  caption: formatItWorkMetaShort(meta),
                  onTap: () => openItWorkLightbox(context, lightboxUrls, idx < 0 ? 0 : idx),
                  onRemove: () => _removeItemNewEvidence(index, pIdx),
                );
              }),
              ...List.generate(existing.length, (eIdx) {
                final ev = existing[eIdx];
                final url = ev['url']?.toString() ?? '';
                final idx = lightboxUrls.indexOf(url);
                final id = _parseInt(ev['id']);
                return _thumb(
                  url: url,
                  caption: formatItWorkExistingMetaShort(ev),
                  onTap: () => openItWorkLightbox(context, lightboxUrls, idx < 0 ? 0 : idx),
                  onRemove: () {
                    if (id != null) _markRemoveEvidence(id);
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit IT Work Report' : 'Buat IT Work Report',
      body: _loading
          ? const Center(child: AppLoadingIndicator(color: ItWorkReportUi.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: ItWorkReportUi.primary),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildVisitSection(),
                            if (_sourceType == 'ticket') _buildTicketSection(),
                            if (_sourceType == 'whatsapp') _buildWaSection(),
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Perangkat dikerjakan',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Evidence wajib dari kamera; foto ditandai tanggal, jam, alamat & koordinat',
                                        style: TextStyle(fontSize: 11, color: ItWorkReportUi.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, color: ItWorkReportUi.primary),
                                  label: const Text('Tambah', style: TextStyle(color: ItWorkReportUi.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(_items.length, (i) => _buildItemCard(i, _items[i])),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: ItWorkReportUi.border)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : () => _save(submit: false),
                              child: const Text('Simpan Draft'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _save(submit: true),
                              style: FilledButton.styleFrom(
                                backgroundColor: ItWorkReportUi.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send, size: 18),
                              label: Text(_saving ? 'Menyimpan...' : 'Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
