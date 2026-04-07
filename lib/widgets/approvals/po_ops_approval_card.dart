import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class POOpsApprovalCard extends StatelessWidget {
  final PurchaseOrderOpsApproval approval;
  final VoidCallback onTap;

  const POOpsApprovalCard({
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
                    color: Colors.orange.shade500,
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
            if (approval.supplierName != null) ...[
              const SizedBox(height: 4),
              Text(
                approval.supplierName!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.prNumber != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: 12,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'PR: ${approval.prNumber}',
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
            if (approval.prTitle != null) ...[
              const SizedBox(height: 2),
              Text(
                approval.prTitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.outletName != null || approval.divisionName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.store,
                    size: 12,
                    color: Colors.blue.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.outletName ?? approval.divisionName ?? '',
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
            if (approval.grandTotal != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatCurrency(approval.grandTotal),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (approval.creator != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 12,
                    color: Colors.blue.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.creator!['nama_lengkap'] ?? '',
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
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
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

