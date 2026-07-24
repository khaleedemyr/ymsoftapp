import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class WfhRequestApprovalCard extends StatelessWidget {
  final WfhRequestApproval approval;
  final VoidCallback onTap;

  const WfhRequestApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
  });

  String _formatTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    const teal = Color(0xFF0D9488);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF99F6E4), width: 1),
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
                    color: teal,
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
              'WFH Approval',
              style: TextStyle(
                fontSize: 12,
                color: teal,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (approval.userName != null && approval.userName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Karyawan: ${approval.userName}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
            if (approval.wfhDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tanggal: ${dateFormat.format(approval.wfhDate!)}'
                '${approval.shiftName != null ? ' · ${approval.shiftName}' : ''}'
                '${approval.timeStart != null ? ' ${_formatTime(approval.timeStart)}–${_formatTime(approval.timeEnd)}' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (approval.reason != null && approval.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                approval.reason!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.approverName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 12, color: teal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F766E),
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
