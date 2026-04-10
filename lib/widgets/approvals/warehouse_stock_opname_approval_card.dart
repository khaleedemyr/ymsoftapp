import 'package:flutter/material.dart';
import '../../models/approval_models.dart';

class WarehouseStockOpnameApprovalCard extends StatelessWidget {
  final WarehouseStockOpnameApproval approval;
  final VoidCallback onTap;

  const WarehouseStockOpnameApprovalCard({
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
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC4B5FD), width: 1),
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
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Stock Opname Gudang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            if (approval.opnameNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.tag, size: 12, color: Colors.deepPurple.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.opnameNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.warehouseName != null && approval.warehouseName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.warehouse, size: 12, color: Colors.deepPurple.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.warehouseName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.divisionName != null && approval.divisionName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.account_tree, size: 12, color: Colors.deepPurple.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.divisionName!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                  Icon(Icons.check_circle, size: 12, color: Colors.deepPurple.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.approverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.deepPurple.shade700,
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
