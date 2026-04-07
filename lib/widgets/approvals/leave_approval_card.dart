import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class LeaveApprovalCard extends StatelessWidget {
  final LeaveApproval approval;
  final VoidCallback onTap;
  final bool isHrd;

  const LeaveApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
    this.isHrd = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHrd ? Colors.purple : Colors.blue;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHrd ? Colors.purple.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHrd ? Colors.purple.shade200 : Colors.blue.shade200,
            width: 1,
          ),
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
                    color: color.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.employeeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (isHrd)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'HRD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${approval.leaveTypeName} • ${approval.durationText}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(approval.dateFrom)} - ${dateFormat.format(approval.dateTo)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            if (approval.approverName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: color.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.shade700,
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

