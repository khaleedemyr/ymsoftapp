import 'package:flutter/material.dart';
import '../../models/employee_onboarding_models.dart';
import '../../screens/employee_onboarding/employee_onboarding_ui.dart';

class EmployeeOnboardingApprovalCard extends StatelessWidget {
  final EoPendingApproval approval;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onRevision;
  final VoidCallback onReject;
  final bool busy;

  const EmployeeOnboardingApprovalCard({
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
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
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
                Text('Minggu ${approval.weekNumber} · ${approval.employeeName ?? '-'}', style: const TextStyle(fontSize: 12, color: EmployeeOnboardingUi.textMuted)),
                Text(approval.templateName ?? '-', style: const TextStyle(fontSize: 12, color: EmployeeOnboardingUi.textMuted)),
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
                _actionButton('Revisi', EmployeeOnboardingUi.primary, onRevision),
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
