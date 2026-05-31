import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'auth_service.dart';

class PayrollService {
  static const String baseUrl = AuthService.baseUrl;

  static const _monthNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Label periode untuk tampilan (mis. "April 2026").
  static String formatPeriodLabel(dynamic month, dynamic year) {
    final m = month is int ? month : int.tryParse(month?.toString() ?? '') ?? 0;
    final y = year is int ? year : int.tryParse(year?.toString() ?? '') ?? 0;
    if (m < 1 || m > 12 || y <= 0) return 'Periode';
    return '${_monthNames[m]} $y';
  }

  static String resolvePeriodLabel(Map<String, dynamic> data) {
    final label = data['periode_label']?.toString().trim();
    if (label != null && label.isNotEmpty) return label;
    return formatPeriodLabel(data['month'], data['year']);
  }

  Future<String?> _getToken() async {
    return AuthService().getToken();
  }

  Future<Map<String, dynamic>> verifyPin(String pin) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Sesi login tidak valid'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/approval-app/payroll/verify-pin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'pin': pin}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return {'success': true, 'message': data['message'] ?? 'PIN benar'};
    }

    return {
      'success': false,
      'message': data['message'] ?? 'PIN salah',
    };
  }

  Future<Map<String, dynamic>> getUserPayrollList() async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Sesi login tidak valid', 'data': []};
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/approval-app/payroll/user-list'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      final raw = data['data'] as List? ?? [];
      final periods = normalizePayrollPeriods(raw);
      return {
        'success': true,
        'data': periods,
      };
    }

    return {
      'success': false,
      'message': data['message'] ?? 'Gagal mengambil data payroll',
      'data': <Map<String, dynamic>>[],
    };
  }

  Future<Map<String, dynamic>> getSlipDetail({
    required dynamic payrollDetailId,
    required String type,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Sesi login tidak valid'};
    }

    final uri = Uri.parse('$baseUrl/api/approval-app/payroll/user-slip-detail').replace(
      queryParameters: {
        'payroll_detail_id': payrollDetailId.toString(),
        'type': type,
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'data': Map<String, dynamic>.from(data['data'] as Map),
      };
    }

    return {
      'success': false,
      'message': data['message'] ?? 'Gagal mengambil detail slip gaji',
    };
  }

  Future<String?> downloadSlipPdf({
    required dynamic payrollDetailId,
    required String type,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/api/approval-app/payroll/user-slip-pdf').replace(
        queryParameters: {
          'payroll_detail_id': payrollDetailId.toString(),
          'type': type,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/slip_gaji_${payrollDetailId}_$type.pdf');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }

      return null;
    } catch (e) {
      print('Error downloading payroll slip PDF: $e');
      return null;
    }
  }

  Future<String?> downloadCombinedSlipPdf({
    required dynamic payrollDetailId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final combinedPath = await _downloadPdfToFile(
        token: token,
        uri: Uri.parse('$baseUrl/api/approval-app/payroll/user-slip-pdf').replace(
          queryParameters: {
            'payroll_detail_id': payrollDetailId.toString(),
            'type': 'combined',
          },
        ),
        outputPath: '${Directory.systemTemp.path}/slip_gaji_$payrollDetailId.pdf',
      );
      if (combinedPath != null) return combinedPath;

      final legacyCombinedPath = await _downloadPdfToFile(
        token: token,
        uri: Uri.parse('$baseUrl/api/approval-app/payroll/user-slip-combined-pdf').replace(
          queryParameters: {
            'payroll_detail_id': payrollDetailId.toString(),
          },
        ),
        outputPath: '${Directory.systemTemp.path}/slip_gaji_$payrollDetailId.pdf',
      );
      if (legacyCombinedPath != null) return legacyCombinedPath;

      final gajian1Path = await downloadSlipPdf(payrollDetailId: payrollDetailId, type: 'gajian1');
      final gajian2Path = await downloadSlipPdf(payrollDetailId: payrollDetailId, type: 'gajian2');
      if (gajian1Path == null) return null;
      if (gajian2Path == null) return gajian1Path;

      return _mergePdfFiles(
        [gajian1Path, gajian2Path],
        '${Directory.systemTemp.path}/slip_gaji_$payrollDetailId.pdf',
      );
    } catch (e) {
      print('Error downloading payroll slip PDF: $e');
      return null;
    }
  }

  Future<String?> _downloadPdfToFile({
    required String token,
    required Uri uri,
    required String outputPath,
  }) async {
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/pdf',
      },
    );

    if (response.statusCode != 200) return null;

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('json')) return null;
    if (response.bodyBytes.length < 100) return null;

    final file = File(outputPath);
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<String?> _mergePdfFiles(List<String> inputPaths, String outputPath) async {
    try {
      final mergedPath = await PdfCombiner.mergeMultiplePDFs(
        inputs: inputPaths.map(MergeInput.path).toList(),
        outputPath: outputPath,
      );
      if (mergedPath.isNotEmpty) return mergedPath;
    } catch (e) {
      print('Error merging payroll PDF files: $e');
    }
    return inputPaths.isNotEmpty ? inputPaths.first : null;
  }

  /// Gabungkan respons API format lama (flat gajian1/gajian2) ke format periode.
  static List<Map<String, dynamic>> normalizePayrollPeriods(List<dynamic> raw) {
    if (raw.isEmpty) return [];

    final first = Map<String, dynamic>.from(raw.first as Map);
    if (first.containsKey('slips')) {
      final deduped = <String, Map<String, dynamic>>{};
      for (final item in raw) {
        final period = Map<String, dynamic>.from(item as Map);
        period['slips'] = List<Map<String, dynamic>>.from(
          (period['slips'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
        );
        final key = period['payroll_detail_id']?.toString() ?? '';
        if (key.isNotEmpty) {
          period['periode_label'] = resolvePeriodLabel(period);
          deduped[key] = period;
        }
      }
      return _sortPeriods(deduped.values.toList());
    }

    final grouped = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      final slip = Map<String, dynamic>.from(item as Map);
      final detailId = slip['payroll_detail_id']?.toString() ?? '';
      final key = detailId.isNotEmpty
          ? detailId
          : '${slip['month']}_${slip['year']}_${slip['outlet_id']}';

      grouped.putIfAbsent(key, () => {
            'payroll_detail_id': slip['payroll_detail_id'],
            'user_id': slip['user_id'],
            'outlet_id': slip['outlet_id'],
            'outlet_name': slip['outlet_name'],
            'month': slip['month'],
            'year': slip['year'],
            'periode': slip['periode'],
            'periode_label': resolvePeriodLabel(slip),
            'total_gaji': 0,
            'slips': <Map<String, dynamic>>[],
          });

      (grouped[key]!['slips'] as List<Map<String, dynamic>>).add(slip);
    }

    for (final period in grouped.values) {
      final slips = period['slips'] as List<Map<String, dynamic>>;
      period['total_gaji'] = slips.fold<num>(
        0,
        (sum, slip) => sum + _asNum(slip['total_gaji']),
      );
    }

    return _sortPeriods(grouped.values.toList());
  }

  static num _asNum(dynamic value) => value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  static List<Map<String, dynamic>> _sortPeriods(List<Map<String, dynamic>> periods) {
    periods.sort((a, b) {
      final yearCompare = _asNum(b['year']).compareTo(_asNum(a['year']));
      if (yearCompare != 0) return yearCompare;
      return _asNum(b['month']).compareTo(_asNum(a['month']));
    });
    return periods;
  }

  /// Isi total per slip & periode jika API list belum menyertakan nominal per gajian.
  Future<List<Map<String, dynamic>>> enrichPeriodTotals(List<Map<String, dynamic>> periods) async {
    final enriched = <Map<String, dynamic>>[];

    for (final period in periods) {
      final copy = Map<String, dynamic>.from(period);
      final slips = List<Map<String, dynamic>>.from(
        (copy['slips'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      num periodTotal = 0;
      for (final slip in slips) {
        var slipTotal = _asNum(slip['total_gaji']);
        if (slipTotal <= 0) {
          final type = slip['type']?.toString() ?? 'gajian1';
          slipTotal = type == 'gajian1'
              ? _asNum(copy['total_gajian1'])
              : _asNum(copy['total_gajian2']);

          if (slipTotal <= 0) {
            final detail = await getSlipDetail(
              payrollDetailId: slip['payroll_detail_id'],
              type: type,
            );
            if (detail['success'] == true) {
              final data = Map<String, dynamic>.from(detail['data'] as Map? ?? {});
              if (type == 'gajian1') {
                final g1 = Map<String, dynamic>.from(data['gajian1'] as Map? ?? {});
                slipTotal = _asNum(g1['total_gaji_gajian1']);
              } else {
                final g2 = Map<String, dynamic>.from(data['gajian2'] as Map? ?? {});
                slipTotal = _asNum(g2['total_gaji_gajian2']);
              }
            }
          }

          slip['total_gaji'] = slipTotal;
        }
        periodTotal += slipTotal;
      }

      if (periodTotal > 0) {
        copy['total_gaji'] = periodTotal;
      }
      copy['slips'] = slips;
      enriched.add(copy);
    }

    return enriched;
  }
}
