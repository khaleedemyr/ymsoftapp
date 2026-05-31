import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/payroll_service.dart';
import '../../widgets/app_scaffold.dart';
import 'payroll_slip_detail_screen.dart';

class PayrollPeriodDetailScreen extends StatelessWidget {
  final Map<String, dynamic> period;

  const PayrollPeriodDetailScreen({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    final slips = List<Map<String, dynamic>>.from(
      (period['slips'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final periodeLabel = PayrollService.resolvePeriodLabel(period);

    return AppScaffold(
      title: 'Detail Periode',
      showDrawer: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPeriodSummary(periodeLabel),
          const SizedBox(height: 16),
          Text(
            'Pilih slip gaji',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          ...slips.map((slip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SlipTile(
                  slip: slip,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PayrollSlipDetailScreen(
                        payrollDetailId: slip['payroll_detail_id'],
                        type: slip['type']?.toString() ?? 'gajian1',
                        title: slip['type_label']?.toString() ?? 'Slip Gaji',
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary(String periodeLabel) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = period['total_gaji'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E40AF)),
          ),
          const SizedBox(height: 6),
          Text(
            period['outlet_name']?.toString() ?? '-',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            currency.format(total is num ? total : num.tryParse(total?.toString() ?? '') ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1D4ED8)),
          ),
          const SizedBox(height: 4),
          Text(
            'Total gaji periode (Gajian 1 + Gajian 2 yang sudah tersedia)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SlipTile extends StatelessWidget {
  final Map<String, dynamic> slip;
  final VoidCallback onTap;

  const _SlipTile({required this.slip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGajian1 = slip['type'] == 'gajian1';
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = slip['total_gaji'];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isGajian1 ? const Color(0xFF2563EB) : const Color(0xFF6366F1)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: isGajian1 ? const Color(0xFF2563EB) : const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slip['type_label']?.toString() ?? 'Slip Gaji',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slip['gajian_date_formatted']?.toString() ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(total is num ? total : num.tryParse(total?.toString() ?? '') ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
