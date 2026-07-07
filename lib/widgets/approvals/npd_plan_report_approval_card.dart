import 'package:flutter/material.dart';
import '../../models/npd_plan_report_models.dart';
import '../../screens/npd_plan_report/npd_plan_report_ui.dart';

class NpdPlanReportApprovalCard extends StatelessWidget {
  final NpdPendingApproval approval;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onRevision;
  final VoidCallback onReject;
  final bool busy;

  const NpdPlanReportApprovalCard({
    super.key,
    required this.approval,
    required this.onOpen,
    required this.onApprove,
    required this.onRevision,
    required this.onReject,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(approval.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${approval.outletName} · ${approval.itemsCount} produk',
                  style: TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted),
                ),
                Text(approval.creatorName ?? '-', style: TextStyle(fontSize: 12, color: NpdPlanReportUi.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (busy)
            const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionButton('Setujui', const Color(0xFF16A34A), onApprove),
                _actionButton('Revisi', NpdPlanReportUi.primary, onRevision),
                _actionButton('Tolak', const Color(0xFFDC2626), onReject),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
