import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/payroll_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';

class PayrollSlipDetailScreen extends StatefulWidget {
  final dynamic payrollDetailId;
  final String type;
  final String title;

  const PayrollSlipDetailScreen({
    super.key,
    required this.payrollDetailId,
    required this.type,
    required this.title,
  });

  @override
  State<PayrollSlipDetailScreen> createState() => _PayrollSlipDetailScreenState();
}

class _PayrollSlipDetailScreenState extends State<PayrollSlipDetailScreen> {
  final PayrollService _payrollService = PayrollService();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  bool _isDownloading = false;
  Map<String, dynamic>? _slip;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _payrollService.getSlipDetail(
      payrollDetailId: widget.payrollDetailId,
      type: widget.type,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _slip = result['success'] == true ? Map<String, dynamic>.from(result['data']) : null;
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Gagal memuat slip gaji')),
      );
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    final path = await _payrollService.downloadSlipPdf(
      payrollDetailId: widget.payrollDetailId,
      type: widget.type,
    );

    if (!mounted) return;

    setState(() => _isDownloading = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengunduh PDF slip gaji')),
      );
      return;
    }

    await OpenFilex.open(path);
  }

  num _num(dynamic value) => value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  String _money(dynamic value) => _currency.format(_num(value));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      showDrawer: false,
      actions: [
        if (!_isLoading && _slip != null)
          IconButton(
            onPressed: _isDownloading ? null : _downloadPdf,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Download PDF',
          ),
      ],
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _slip == null
              ? const Center(child: Text('Data slip gaji tidak ditemukan'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      if (widget.type == 'gajian1') _buildGajian1() else _buildGajian2(),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isDownloading ? null : _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(_isDownloading ? 'Mengunduh PDF...' : 'Download PDF Slip Gaji'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _infoRow('Nama', _slip!['nama_lengkap']?.toString() ?? '-'),
          _infoRow('NIK', _slip!['nik']?.toString() ?? '-'),
          _infoRow('Jabatan', _slip!['jabatan']?.toString() ?? '-'),
          _infoRow('Divisi', _slip!['divisi']?.toString() ?? '-'),
          _infoRow('Outlet', _slip!['outlet_name']?.toString() ?? '-'),
          _infoRow('Periode', PayrollService.resolvePeriodLabel(_slip!)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildGajian1() {
    final g = Map<String, dynamic>.from(_slip!['gajian1'] as Map? ?? {});
    final leaveData = Map<String, dynamic>.from(g['leave_data'] as Map? ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Pendapatan',
          titleColor: Colors.green.shade700,
          titleBg: Colors.green.shade50,
          children: [
            _lineRow('Gaji Pokok', _money(g['gaji_pokok'])),
            _lineRow('Tunjangan', _money(g['tunjangan'])),
            ..._customItems(g['custom_earning_items'], isEarn: true),
            if (_num(g['custom_earnings']) > 0 && (g['custom_earning_items'] as List? ?? []).isEmpty)
              _lineRow('Custom Earning', _money(g['custom_earnings'])),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Potongan',
          titleColor: Colors.red.shade700,
          titleBg: Colors.red.shade50,
          children: [
            ..._customItems(g['custom_deduction_items'], isEarn: false),
            if (_num(g['custom_deductions']) > 0 && (g['custom_deduction_items'] as List? ?? []).isEmpty)
              _lineRow('Custom Deduction', _money(g['custom_deductions']), isDeduction: true),
            if (_num(g['bpjs_jkn']) > 0)
              _lineRow('BPJS Kesehatan (JKN)', _money(g['bpjs_jkn']), isDeduction: true),
            if (_num(g['bpjs_tk']) > 0)
              _lineRow('BPJS Ketenagakerjaan (TK)', _money(g['bpjs_tk']), isDeduction: true),
            if (_num(g['potongan_telat']) > 0)
              _lineRow(
                'Potongan Telat',
                _money(g['potongan_telat']),
                isDeduction: true,
                subtitle: '${g['total_telat'] ?? 0} menit · @ ${_money(g['gaji_per_menit'] ?? 500)}/menit',
              ),
            if (_num(g['potongan_alpha']) + _num(g['potongan_unpaid_leave']) > 0)
              _lineRow(
                'Alpha & Unpaid Leave',
                _money(_num(g['potongan_alpha']) + _num(g['potongan_unpaid_leave'])),
                isDeduction: true,
                subtitle: 'Alpha: ${g['total_alpha'] ?? 0} hari',
              ),
            if (_num(g['potongan_kasbon']) > 0)
              _lineRow(
                'Potongan Kasbon',
                _money(g['potongan_kasbon']),
                isDeduction: true,
                subtitle: _kasbonSubtitle(g),
              ),
          ],
        ),
        if (leaveData.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Leave Breakdown',
            titleColor: Colors.blue.shade700,
            titleBg: Colors.blue.shade50,
            children: leaveData.entries
                .where((e) => e.key.toString().endsWith('_days') && _num(e.value) > 0)
                .map((e) => _lineRow(e.key.toString().replaceAll('_days', '').replaceAll('_', ' '), '${e.value} hari'))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        _totalCard('Total Gaji Bersih', _money(g['total_gaji_gajian1']), Colors.blue),
      ],
    );
  }

  Widget _buildGajian2() {
    final g = Map<String, dynamic>.from(_slip!['gajian2'] as Map? ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Pendapatan',
          titleColor: Colors.green.shade700,
          titleBg: Colors.green.shade50,
          children: [
            if (_num(g['service_charge_by_point']) > 0)
              _lineRow('Service Charge (By Point)', _money(g['service_charge_by_point'])),
            if (_num(g['service_charge_pro_rate']) > 0)
              _lineRow('Service Charge (Pro Rate)', _money(g['service_charge_pro_rate'])),
            if (_num(g['uang_makan']) > 0)
              _lineRow(
                'Uang Makan',
                _money(g['uang_makan']),
                subtitle: '${g['hari_kerja'] ?? '-'} hari kerja'
                    '${_num(g['nominal_uang_makan']) > 0 ? ' · @ ${_money(g['nominal_uang_makan'])}/hari' : ''}',
              ),
            if (_num(g['gaji_lembur']) > 0)
              _lineRow(
                'Lembur',
                _money(g['gaji_lembur']),
                subtitle: '${g['total_lembur'] ?? 0} jam'
                    '${_num(g['nominal_lembur_per_jam']) > 0 ? ' · @ ${_money(g['nominal_lembur_per_jam'])}/jam' : ''}',
              ),
            if (_num(g['ph_bonus']) > 0) _lineRow('PH Bonus', _money(g['ph_bonus'])),
            ..._customItems(g['custom_earning_items'], isEarn: true),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Potongan',
          titleColor: Colors.red.shade700,
          titleBg: Colors.red.shade50,
          children: [
            ..._customItems(g['custom_deduction_items'], isEarn: false),
            if (_num(g['lb_total']) > 0) _lineRow('L & B', _money(g['lb_total']), isDeduction: true),
            if (_num(g['deviasi_total']) > 0) _lineRow('Deviasi', _money(g['deviasi_total']), isDeduction: true),
            if (_num(g['city_ledger_total']) > 0)
              _lineRow('City Ledger', _money(g['city_ledger_total']), isDeduction: true),
          ],
        ),
        const SizedBox(height: 12),
        _totalCard('Total Gaji Bersih', _money(g['total_gaji_gajian2']), Colors.indigo),
      ],
    );
  }

  String _kasbonSubtitle(Map<String, dynamic> g) {
    final parts = <String>[];
    final prNumber = g['kasbon_pr_number']?.toString();
    final cicilanKe = g['kasbon_cicilan_ke'];
    if (prNumber != null && prNumber.isNotEmpty) {
      parts.add('PR: $prNumber');
    }
    if (cicilanKe != null && cicilanKe.toString().isNotEmpty) {
      parts.add('Cicilan ke-$cicilanKe');
    }
    return parts.join(' · ');
  }

  List<Widget> _customItems(dynamic items, {required bool isEarn}) {
    final list = items as List? ?? [];
    return list.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return _lineRow(
        item['name']?.toString() ?? 'Custom Item',
        _money(item['amount']),
        isDeduction: !isEarn,
        subtitle: item['description']?.toString(),
      );
    }).toList();
  }

  Widget _sectionCard({
    required String title,
    required Color titleColor,
    required Color titleBg,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: titleBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(String label, String amount, {bool isDeduction = false, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}$amount',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDeduction ? Colors.red.shade700 : Colors.green.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String label, String amount, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color.shade800)),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color.shade800)),
        ],
      ),
    );
  }
}
