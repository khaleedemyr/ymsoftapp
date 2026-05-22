import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval_models.dart';

class AssetOwnerTransferApprovalCard extends StatelessWidget {
  final AssetOwnerTransferApproval approval;
  final VoidCallback onTap;

  const AssetOwnerTransferApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
  });

  static const Color _violet = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _violet.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _violet.withOpacity(0.35), width: 1),
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
                    color: _violet,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.transferNumber ?? 'No Number',
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
              'Transfer Kepemilikan Aset',
              style: TextStyle(
                fontSize: 12,
                color: _violet,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (approval.ownerFromName != null || approval.ownerToName != null) ...[
              const SizedBox(height: 4),
              Text(
                '${approval.ownerFromName ?? '-'} → ${approval.ownerToName ?? '-'}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (approval.creatorName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 12,
                    color: _violet.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.creatorName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _violet.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (approval.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                dateFormat.format(approval.createdAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
