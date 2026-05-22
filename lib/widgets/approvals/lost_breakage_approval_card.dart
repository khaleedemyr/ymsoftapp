import 'package:flutter/material.dart';
import '../../models/approval_models.dart';

class LostBreakageApprovalCard extends StatelessWidget {
  final LostBreakageApproval approval;
  final VoidCallback onTap;

  const LostBreakageApprovalCard({
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
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1),
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
                    color: Colors.orange.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.number ?? 'No Number',
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
              'Asset Lost & Breakage',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepOrange,
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
            if (approval.creatorName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.creatorName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.date != null) ...[
              const SizedBox(height: 4),
              Text(
                approval.date!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
