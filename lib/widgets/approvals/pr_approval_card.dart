import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class PRApprovalCard extends StatelessWidget {
  final PurchaseRequisitionApproval approval;
  final VoidCallback onTap;

  const PRApprovalCard({
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

  String _modeLabel(String? mode) {
    switch ((mode ?? '').toLowerCase()) {
      case 'pr_ops':
        return 'PR Ops';
      case 'purchase_payment':
        return 'Payment';
      case 'travel_application':
        return 'Travel';
      case 'kasbon':
        return 'Kasbon';
      default:
        return mode ?? '';
    }
  }

  Color _modeBadgeColor(String? mode) {
    switch ((mode ?? '').toLowerCase()) {
      case 'kasbon':
        return Colors.orange.shade100;
      case 'travel_application':
        return Colors.purple.shade100;
      case 'purchase_payment':
        return Colors.blue.shade100;
      case 'pr_ops':
        return Colors.teal.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _modeBadgeTextColor(String? mode) {
    switch ((mode ?? '').toLowerCase()) {
      case 'kasbon':
        return Colors.orange.shade900;
      case 'travel_application':
        return Colors.purple.shade900;
      case 'purchase_payment':
        return Colors.blue.shade900;
      case 'pr_ops':
        return Colors.teal.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          approval.prNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (approval.mode != null && approval.mode!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _modeBadgeColor(approval.mode),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _modeLabel(approval.mode),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _modeBadgeTextColor(approval.mode),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (approval.unreadCommentsCount != null && approval.unreadCommentsCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${approval.unreadCommentsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
            const SizedBox(height: 4),
            Row(
              children: [
                if (approval.divisionName != null) ...[
                  Flexible(
                    child: Text(
                      approval.divisionName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (approval.amount != null) ...[
                    Text(
                      ' • ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
                if (approval.amount != null)
                  Flexible(
                    child: Text(
                      _formatCurrency(approval.amount),
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
            if (approval.outletName != null) ...[
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
                      approval.outletName!,
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
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
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

