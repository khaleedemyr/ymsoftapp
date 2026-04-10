import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class CctvAccessRequestApprovalCard extends StatelessWidget {
  final CctvAccessRequestApproval approval;
  final VoidCallback onTap;

  const CctvAccessRequestApprovalCard({
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
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade200, width: 1),
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
                    color: Colors.blueGrey.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Akses CCTV',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.videocam, size: 12, color: Colors.blueGrey.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    approval.accessTypeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (approval.requesterName != null && approval.requesterName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 12, color: Colors.blueGrey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.requesterName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.outletCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.store, size: 12, color: Colors.blueGrey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${approval.outletCount} outlet',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (approval.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(approval.createdAt!.toLocal()),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
