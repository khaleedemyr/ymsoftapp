import 'package:flutter/material.dart';
import '../../models/sop_development_completion_models.dart';
import '../../screens/sop_development_completion/sop_development_completion_ui.dart';

class SopDevelopmentCompletionApprovalCard extends StatelessWidget {
  final SopPendingApproval approval;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool busy;

  const SopDevelopmentCompletionApprovalCard({
    super.key,
    required this.approval,
    required this.onOpen,
    required this.onApprove,
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
                Text(approval.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  approval.creatorName ?? '-',
                  style: const TextStyle(fontSize: 12, color: SopDevelopmentCompletionUi.textMuted),
                ),
                Text(
                  'Due: ${SopDevelopmentCompletionUi.formatDate(approval.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: SopDevelopmentCompletionUi.textMuted),
                ),
                if (approval.approvalLevel != null)
                  Text(
                    'Level ${approval.approvalLevel}: ${approval.approverName ?? '-'}',
                    style: const TextStyle(fontSize: 11, color: SopDevelopmentCompletionUi.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (busy)
            const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Setujui'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onReject,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
