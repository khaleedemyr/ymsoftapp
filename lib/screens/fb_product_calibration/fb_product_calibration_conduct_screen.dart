import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/fb_product_calibration_models.dart';
import '../../services/fb_product_calibration_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'fb_product_calibration_ui.dart';

class FbProductCalibrationConductScreen extends StatefulWidget {
  final int recordId;

  const FbProductCalibrationConductScreen({super.key, required this.recordId});

  @override
  State<FbProductCalibrationConductScreen> createState() => _FbProductCalibrationConductScreenState();
}

class _FbProductCalibrationConductScreenState extends State<FbProductCalibrationConductScreen> {
  final _service = FbProductCalibrationService();
  final _participantSearchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Timer? _searchTimer;

  Map<String, dynamic>? _record;
  List<CalibrationProductLine> _products = [];
  List<ParameterOption> _parameterOptions = [];
  List<CalibrationParticipant> _participants = [];
  List<UserSuggestion> _participantSuggestions = [];
  bool _showSuggestions = false;

  final Map<String, Map<String, String>> _resultState = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _participantSearchController.dispose();
    super.dispose();
  }

  String _resultKey(int userId, int productId) => '${userId}_$productId';

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getConductData(widget.recordId);
    if (!mounted) return;

    if (res == null || res['success'] != true) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res?['message']?.toString() ?? 'Gagal memuat data conduct')),
      );
      return;
    }

    _record = Map<String, dynamic>.from(res['record'] as Map);
    _products = (_record!['products'] as List? ?? [])
        .map((e) => CalibrationProductLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _parameterOptions = (res['parameter_options'] as List? ?? [])
        .map((e) => ParameterOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _participants = (res['initial_participants'] as List? ?? [])
        .map((e) => CalibrationParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    _resultState.clear();
    for (final row in (res['initial_results'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(row as Map);
      final userId = m['user_id'] as int;
      final productId = m['calibration_product_id'] as int;
      final key = _resultKey(userId, productId);
      _resultState[key] = {};
      for (final param in _parameterOptions) {
        final val = m[param.code]?.toString();
        if (val == 'C' || val == 'NC') {
          _resultState[key]![param.code] = val!;
        }
      }
    }

    _searchParticipants('');
    setState(() => _loading = false);
  }

  void _searchParticipants(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _service.searchParticipants(query);
      if (!mounted) return;
      final selectedIds = _participants.map((p) => p.userId).toSet();
      setState(() {
        _participantSuggestions = results
            .map(UserSuggestion.fromJson)
            .where((u) => !selectedIds.contains(u.id))
            .toList();
        _showSuggestions = query.isNotEmpty && _participantSuggestions.isNotEmpty;
      });
    });
  }

  void _addParticipant(UserSuggestion user) {
    if (_participants.any((p) => p.userId == user.id)) return;
    setState(() {
      _participants.add(CalibrationParticipant(
        userId: user.id,
        userName: user.namaLengkap,
        jabatanName: user.jabatanName,
      ));
      _participantSearchController.clear();
      _showSuggestions = false;
    });
  }

  void _removeParticipant(CalibrationParticipant p) {
    setState(() {
      _participants.removeWhere((x) => x.userId == p.userId);
      _resultState.removeWhere((k, _) => k.startsWith('${p.userId}_'));
    });
  }

  void _setValue(int userId, int productId, String paramCode, String value) {
    final key = _resultKey(userId, productId);
    _resultState.putIfAbsent(key, () => {});
    _resultState[key]![paramCode] = value;
    setState(() {});
  }

  String? _getValue(int userId, int productId, String paramCode) {
    return _resultState[_resultKey(userId, productId)]?[paramCode];
  }

  bool _validate() {
    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan minimal satu user')));
      return false;
    }
    for (final participant in _participants) {
      for (final product in _products) {
        final productId = product.calibrationProductId ?? 0;
        for (final param in _parameterOptions) {
          if (_getValue(participant.userId, productId, param.code) == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Lengkapi: ${participant.userName}, ${product.itemName}, ${param.label}',
                ),
              ),
            );
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    final results = <Map<String, dynamic>>[];
    for (final participant in _participants) {
      for (final product in _products) {
        final productId = product.calibrationProductId ?? 0;
        final entry = <String, dynamic>{
          'user_id': participant.userId,
          'calibration_product_id': productId,
        };
        for (final param in _parameterOptions) {
          entry[param.code] = _getValue(participant.userId, productId, param.code);
        }
        results.add(entry);
      }
    }

    final res = await _service.saveConduct(
      recordId: widget.recordId,
      payload: {
        'participants': _participants.map((p) => p.toPayload()).toList(),
        'results': results,
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Berhasil')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Gagal')));
    }
  }

  Widget _cnNcRow(int userId, int productId, ParameterOption param) {
    final current = _getValue(userId, productId, param.code);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(param.label, style: const TextStyle(fontSize: 13))),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'C', label: Text('C', style: TextStyle(fontWeight: FontWeight.w700))),
              ButtonSegment(value: 'NC', label: Text('NC', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
            emptySelectionAllowed: true,
            selected: current != null ? {current} : <String>{},
            onSelectionChanged: (s) {
              if (s.isEmpty) {
                _resultState[_resultKey(userId, productId)]?.remove(param.code);
                setState(() {});
              } else {
                _setValue(userId, productId, param.code, s.first);
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Conduct Calibration',
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_record?['outlet_name']} · ${FbCalibrationUi.formatDate(_record?['scheduled_date']?.toString())} · ${FbCalibrationUi.modeLabel(_record?['mode']?.toString(), modeLabelFromApi: _record?['mode_label']?.toString())}',
                          style: const TextStyle(color: FbCalibrationUi.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: FbCalibrationUi.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('User yang di-calibration test', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _participantSearchController,
                                decoration: const InputDecoration(
                                  hintText: 'Cari user...',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (v) => _searchParticipants(v),
                              ),
                              if (_showSuggestions)
                                ..._participantSuggestions.map((u) => ListTile(
                                      dense: true,
                                      title: Text(u.namaLengkap),
                                      subtitle: Text(u.jabatanName),
                                      onTap: () => _addParticipant(u),
                                    )),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _participants.map((p) {
                                  return Chip(
                                    label: Text(p.userName),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () => _removeParticipant(p),
                                    backgroundColor: const Color(0xFFEDE9FE),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        if (_participants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._participants.map((participant) {
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
                                        Text(participant.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        Text(participant.jabatanName, style: const TextStyle(fontSize: 12, color: FbCalibrationUi.textMuted)),
                                      ],
                                    ),
                                  ),
                                  ..._products.map((product) {
                                    final productId = product.calibrationProductId ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (product.categoryName != null)
                                            Text(product.categoryName!, style: const TextStyle(fontSize: 11, color: FbCalibrationUi.textMuted)),
                                          const SizedBox(height: 8),
                                          ..._parameterOptions.map((param) => _cnNcRow(participant.userId, productId, param)),
                                          const Divider(),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_saving || _participants.isEmpty) ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: FbCalibrationUi.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Simpan Hasil Calibration'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
