import 'package:flutter/material.dart';
import '../../models/fb_product_calibration_models.dart';
import '../../services/fb_product_calibration_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'fb_product_calibration_conduct_screen.dart';
import 'fb_product_calibration_form_screen.dart';
import 'fb_product_calibration_ui.dart';

class FbProductCalibrationDetailScreen extends StatefulWidget {
  final int recordId;

  const FbProductCalibrationDetailScreen({super.key, required this.recordId});

  @override
  State<FbProductCalibrationDetailScreen> createState() => _FbProductCalibrationDetailScreenState();
}

class _FbProductCalibrationDetailScreenState extends State<FbProductCalibrationDetailScreen> {
  final _service = FbProductCalibrationService();

  bool _loading = true;
  Map<String, dynamic>? _record;
  List<CalibrationProductLine> _products = [];
  List<ParameterOption> _parameterOptions = [];
  bool _canConduct = false;
  Map<String, dynamic>? _conductPayload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDetail(widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat detail')));
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _products = (_record!['products'] as List? ?? [])
        .map((e) => CalibrationProductLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _parameterOptions = (res['parameter_options'] as List? ?? [])
        .map((e) => ParameterOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _canConduct = res['can_conduct'] == true;
    _conductPayload = res['conduct_payload'] != null
        ? Map<String, dynamic>.from(res['conduct_payload'] as Map)
        : null;

    setState(() => _loading = false);
  }

  String? _getResult(int userId, int productId, String paramCode) {
    final results = _conductPayload?['results'] as List? ?? [];
    for (final row in results) {
      final m = Map<String, dynamic>.from(row as Map);
      if (m['user_id'] == userId && m['calibration_product_id'] == productId) {
        return m[paramCode]?.toString();
      }
    }
    return null;
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text('Hapus jadwal ${_record?['outlet_name']}?'),
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
    if (ok != true || !mounted) return;
    final res = await _service.delete(widget.recordId);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _record?['status']?.toString() ?? '';

    return AppScaffold(
      title: 'Detail Calibration',
      actions: [
        if (!_loading)
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
      ],
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: FbCalibrationUi.headerGradient.copyWith(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_record?['outlet_name']?.toString() ?? '-', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(FbCalibrationUi.formatDate(_record?['scheduled_date']?.toString()), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: FbCalibrationUi.cardDecoration,
                    child: Column(
                      children: [
                        _row('Conducted By', _record?['conductor_name']?.toString() ?? '-'),
                        _row('Mode', FbCalibrationUi.modeLabel(
                          _record?['mode']?.toString(),
                          modeLabelFromApi: _record?['mode_label']?.toString(),
                        )),
                        _row('Status', FbCalibrationUi.statusLabel(status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Products', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._products.map((p) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: FbCalibrationUi.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              [p.categoryName, p.subCategoryName].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                              style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted),
                            ),
                          ],
                        ),
                      )),
                  if (_canConduct) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FbProductCalibrationConductScreen(recordId: widget.recordId),
                            ),
                          );
                          if (mounted) _load();
                        },
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(status == 'completed' ? 'Edit Conduct' : 'Conduct Calibration'),
                        style: FilledButton.styleFrom(backgroundColor: FbCalibrationUi.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                  if (status != 'completed' && _canConduct)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: const Text(
                        'Calibration belum dilakukan. Klik Conduct Calibration untuk mulai input hasil test.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF5B21B6)),
                      ),
                    ),
                  if (status == 'completed' && _conductPayload != null) ...[
                    const SizedBox(height: 20),
                    const Text('Hasil Calibration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ...((_conductPayload!['participants'] as List? ?? []).map((p) {
                      final participant = CalibrationParticipant.fromJson(Map<String, dynamic>.from(p as Map));
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: FbCalibrationUi.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(participant.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(participant.jabatanName, style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted)),
                                ],
                              ),
                            ),
                            ..._products.map((product) {
                              final productId = product.calibrationProductId ?? 0;
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    ..._parameterOptions.map((param) {
                                      final val = _getResult(participant.userId, productId, param.code);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(param.label, style: const TextStyle(fontSize: 12))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: val == 'C' ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                val ?? '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: val == 'C' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    })),
                  ],
                  if (status != 'completed') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FbProductCalibrationFormScreen(recordId: widget.recordId)),
                        );
                        if (mounted) _load();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Jadwal'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: FbCalibrationUi.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
