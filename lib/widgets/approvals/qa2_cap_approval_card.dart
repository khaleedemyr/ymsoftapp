import 'package:flutter/material.dart';
import '../../models/approval_models.dart';

class Qa2CapApprovalCard extends StatelessWidget {
  final Qa2CapApproval approval;
  final VoidCallback onTap;

  const Qa2CapApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.auditNumber ?? 'N/A',
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
              'QA2 CAP Approval',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (approval.outletName != null) ...[
              const SizedBox(height: 4),
              Text(
                approval.outletName!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.submitterName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: Colors.indigo.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.submitterName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.indigo.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.ncCount != null) ...[
              const SizedBox(height: 4),
              Text(
                '${approval.ncCount} parameter NC',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
