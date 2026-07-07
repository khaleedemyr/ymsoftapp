class AssetInventoryAdjustment {
  final int id;
  final String number;
  final String date;
  final int? outletId;
  final int? warehouseOutletId;
  final String type; // in / out
  final String? reason;
  final String status;
  final String? creatorName;
  final String? ownerOutletName;
  final String? outletName;
  final String? warehouseOutletName;
  final bool canApprove;
  final List<AssetInventoryAdjustmentItem> items;
  final List<AssetInventoryAdjustmentApprovalFlow> approvalFlows;
  final String? createdAt;

  AssetInventoryAdjustment({
    required this.id,
    required this.number,
    required this.date,
    this.outletId,
    this.warehouseOutletId,
    required this.type,
    this.reason,
    required this.status,
    this.creatorName,
    this.ownerOutletName,
    this.outletName,
    this.warehouseOutletName,
    this.canApprove = false,
    this.items = const [],
    this.approvalFlows = const [],
    this.createdAt,
  });

  factory AssetInventoryAdjustment.fromJson(Map<String, dynamic> json) {
    return AssetInventoryAdjustment(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      outletId: json['outlet_id'] != null ? int.tryParse(json['outlet_id'].toString()) : null,
      warehouseOutletId: json['warehouse_outlet_id'] != null
          ? int.tryParse(json['warehouse_outlet_id'].toString())
          : null,
      type: json['type']?.toString() ?? 'in',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      creatorName: json['creator_name']?.toString(),
      ownerOutletName: json['owner_outlet_name']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      canApprove: json['can_approve'] == true,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AssetInventoryAdjustmentItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvalFlows: (json['approval_flows'] as List<dynamic>?)
              ?.map((e) => AssetInventoryAdjustmentApprovalFlow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString(),
    );
  }
}

class AssetInventoryAdjustmentItem {
  final int id;
  final int? adjustmentId;
  final int itemId;
  final double qty;
  final String? unit;
  final String? note;
  final String? itemName;

  AssetInventoryAdjustmentItem({
    required this.id,
    this.adjustmentId,
    required this.itemId,
    this.qty = 0,
    this.unit,
    this.note,
    this.itemName,
  });

  factory AssetInventoryAdjustmentItem.fromJson(Map<String, dynamic> json) {
    return AssetInventoryAdjustmentItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      adjustmentId: json['adjustment_id'] != null
          ? int.tryParse(json['adjustment_id'].toString())
          : null,
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString(),
      note: json['note']?.toString(),
      itemName: json['item_name']?.toString(),
    );
  }
}

class AssetInventoryAdjustmentApprovalFlow {
  final int id;
  final int? adjustmentId;
  final int approverId;
  final int approvalLevel;
  final String status;
  final String? approvedAt;
  final String? rejectedAt;
  final String? comments;
  final String? approverName;
  final String? approverJabatan;

  AssetInventoryAdjustmentApprovalFlow({
    required this.id,
    this.adjustmentId,
    required this.approverId,
    required this.approvalLevel,
    required this.status,
    this.approvedAt,
    this.rejectedAt,
    this.comments,
    this.approverName,
    this.approverJabatan,
  });

  factory AssetInventoryAdjustmentApprovalFlow.fromJson(Map<String, dynamic> json) {
    return AssetInventoryAdjustmentApprovalFlow(
      id: int.tryParse(json['id'].toString()) ?? 0,
      adjustmentId: json['adjustment_id'] != null
          ? int.tryParse(json['adjustment_id'].toString())
          : null,
      approverId: int.tryParse(json['approver_id']?.toString() ?? '0') ?? 0,
      approvalLevel: int.tryParse(json['approval_level']?.toString() ?? '1') ?? 1,
      status: json['status']?.toString() ?? 'PENDING',
      approvedAt: json['approved_at']?.toString(),
      rejectedAt: json['rejected_at']?.toString(),
      comments: json['comments']?.toString(),
      approverName: json['approver_name']?.toString(),
      approverJabatan: json['approver_jabatan']?.toString(),
    );
  }
}
