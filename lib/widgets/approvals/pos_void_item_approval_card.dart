import 'package:flutter/material.dart';
import '../../models/approval_models.dart';

String _outletLine(PosVoidItemApproval a) {
  final name = a.outletName?.trim() ?? '';
  final code = a.outletCode?.trim() ?? '';
  if (code.isNotEmpty && code != name) {
    return 'Outlet: $name · $code';
  }
  return 'Outlet: $name';
}

class PosVoidItemApprovalCard extends StatefulWidget {
  final PosVoidItemApproval approval;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const PosVoidItemApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<PosVoidItemApprovalCard> createState() => _PosVoidItemApprovalCardState();
}

class _PosVoidItemApprovalCardState extends State<PosVoidItemApprovalCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Colors.deepOrange;

    return Opacity(
      opacity: _busy ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.shade200),
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
                    color: c.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.approval.number ??
                        widget.approval.orderNomor ??
                        widget.approval.orderId ??
                        '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Void',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'POS — Void Item',
              style: TextStyle(
                fontSize: 12,
                color: c.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.approval.itemName != null &&
                widget.approval.itemName!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.approval.itemName!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (widget.approval.outletName != null &&
                widget.approval.outletName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _outletLine(widget.approval),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
            if (widget.approval.creatorName != null &&
                widget.approval.creatorName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: c.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.approval.creatorName!,
                      style: TextStyle(fontSize: 11, color: c.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (widget.approval.reason != null &&
                widget.approval.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.approval.reason!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (widget.approval.date != null &&
                widget.approval.date!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.approval.date!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(widget.onReject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(_busy ? '…' : 'Tolak', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _run(widget.onApprove),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: _busy
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Setujui', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
