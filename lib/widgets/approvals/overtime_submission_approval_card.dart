import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class OvertimeSubmissionApprovalCard extends StatelessWidget {
  final OvertimeSubmissionApproval approval;
  final VoidCallback onTap;

  const OvertimeSubmissionApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Overtime Submission',
              style: TextStyle(
                fontSize: 12,
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (approval.creatorName != null && approval.creatorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pembuat: ${approval.creatorName}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
            if (approval.submissionDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tanggal: ${dateFormat.format(approval.submissionDate!)} · ${approval.employeeCount} karyawan · ${approval.totalHours} jam',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (approval.approverName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.indigo.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
