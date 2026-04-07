import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class PRFoodApprovalCard extends StatelessWidget {
  final PRFoodApproval approval;
  final VoidCallback onTap;

  const PRFoodApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
  });

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    // Use default locale to avoid locale initialization issues
    final formatter = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.lime.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.lime.shade200, width: 1),
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
                    color: Colors.lime.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.prNumber ?? 'PR Food',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            if (approval.title != null) ...[
              const SizedBox(height: 4),
              Text(
                approval.title!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.amount != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatCurrency(approval.amount),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (approval.warehouse != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.warehouse, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.warehouse!['name'] ?? approval.warehouse.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.requester != null && approval.requester!['nama_lengkap'] != null ||
                approval.creatorName != null ||
                (approval.creator != null && approval.creator!['nama_lengkap'] != null)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.requester?['nama_lengkap'] ??
                          approval.creatorName ??
                          approval.creator?['nama_lengkap'] ??
                          '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.approverName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: Colors.lime.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.lime.shade700,
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

