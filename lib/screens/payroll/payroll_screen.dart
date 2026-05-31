import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/auth_service.dart';
import '../../services/payroll_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_loading_indicator.dart';
import 'payroll_period_detail_screen.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  final _pinController = TextEditingController();
  final _pinFormKey = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _pinVerified = false;
  bool _isVerifying = false;
  bool _isLoadingList = false;
  int? _downloadingPeriodId;
  List<Map<String, dynamic>> _periodList = [];

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (!_pinFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isVerifying = true);
    final result = await _payrollService.verifyPin(_pinController.text.trim());
    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (result['success'] == true) {
      setState(() => _pinVerified = true);
      await _loadPayrollList();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'PIN salah')),
    );
  }

  Future<void> _loadPayrollList() async {
    setState(() => _isLoadingList = true);
    final result = await _payrollService.getUserPayrollList();
    if (!mounted) return;

    List<Map<String, dynamic>> periods = [];
    if (result['success'] == true) {
      periods = List<Map<String, dynamic>>.from(result['data'] ?? []);
      periods = await _payrollService.enrichPeriodTotals(periods);
    }

    if (!mounted) return;

    setState(() {
      _isLoadingList = false;
      _periodList = periods;
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Gagal memuat payroll')),
      );
    }
  }

  num _num(dynamic value) => value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _downloadCombinedPdf(Map<String, dynamic> period) async {
    final periodId = period['payroll_detail_id'];
    if (_downloadingPeriodId != null) return;

    setState(() => _downloadingPeriodId = periodId is int ? periodId : int.tryParse(periodId.toString()));

    final path = await _payrollService.downloadCombinedSlipPdf(
      payrollDetailId: periodId,
    );

    if (!mounted) return;
    setState(() => _downloadingPeriodId = null);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengunduh PDF slip gaji')),
      );
      return;
    }

    await OpenFilex.open(path);
  }

  Future<void> _openPeriod(Map<String, dynamic> period) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayrollPeriodDetailScreen(period: period),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Payroll',
      showDrawer: false,
      body: _pinVerified ? _buildListView() : _buildPinView(),
    );
  }

  Widget _buildPinView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _pinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, size: 36, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Masukkan PIN Payroll',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PIN diperlukan untuk melihat slip gaji Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    decoration: InputDecoration(
                      labelText: 'PIN Payroll',
                      prefixIcon: const Icon(Icons.pin, color: Color(0xFF6366F1)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'PIN Payroll wajib diisi';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _verifyPin(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Verifikasi PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_isLoadingList) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_periodList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Tidak ada slip gaji tersedia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Slip gaji akan muncul setelah payroll di-generate dan tanggal gajian tiba',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayrollList,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _periodList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final period = _periodList[index];
          final periodId = period['payroll_detail_id'];
          final isDownloading = _downloadingPeriodId != null &&
              _downloadingPeriodId.toString() == periodId.toString();
          final periodeLabel = PayrollService.resolvePeriodLabel(period);
          final slipCount = (period['slips'] as List? ?? []).length;

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openPeriod(period),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                periodeLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                period['outlet_name']?.toString() ?? '-',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$slipCount slip tersedia',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Gaji Periode',
                            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            _currency.format(_num(period['total_gaji'])),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isDownloading ? null : () => _downloadCombinedPdf(period),
                        icon: isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf, size: 20),
                        label: Text(isDownloading ? 'Mengunduh PDF...' : 'Download PDF Slip Gaji'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper untuk cek PIN payroll sebelum buka halaman
Future<void> openPayrollScreen(BuildContext context) async {
  final authService = AuthService();
  final userData = await authService.getUserData();
  final pinPayroll = userData?['pin_payroll']?.toString().trim() ?? '';
  final hasPin = pinPayroll.isNotEmpty && pinPayroll != 'null';

  if (!hasPin) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN Payroll Belum Diatur'),
        content: const Text('Silakan isi PIN Payroll terlebih dahulu di menu Profil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const PayrollScreen()),
  );
}
