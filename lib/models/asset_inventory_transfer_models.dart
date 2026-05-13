class AssetInventoryTransfer {
  final int id;
  final String transferNumber;
  final String transferDate;
  final String status;
  final String? notes;
  final String? creatorName;
  final String? outletFromName;
  final String? outletToName;
  final String? warehouseOutletFromName;
  final String? warehouseOutletToName;
  final String? approvalByName;
  final String? approvalAt;
  final String? approvalNotes;
  final bool canApprove;
  final List<AssetInventoryTransferItem> items;
  final List<AssetInventoryTransferApprovalFlow> approvalFlows;
  final String? createdAt;

  AssetInventoryTransfer({
    required this.id,
    required this.transferNumber,
    required this.transferDate,
    required this.status,
    this.notes,
    this.creatorName,
    this.outletFromName,
    this.outletToName,
    this.warehouseOutletFromName,
    this.warehouseOutletToName,
    this.approvalByName,
    this.approvalAt,
    this.approvalNotes,
    this.canApprove = false,
    this.items = const [],
    this.approvalFlows = const [],
    this.createdAt,
  });

  factory AssetInventoryTransfer.fromJson(Map<String, dynamic> json) {
    return AssetInventoryTransfer(
      id: int.tryParse(json['id'].toString()) ?? 0,
      transferNumber: json['transfer_number']?.toString() ?? '',
      transferDate: json['transfer_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      notes: json['notes']?.toString(),
      creatorName: json['creator_name']?.toString(),
      outletFromName: json['outlet_from_name']?.toString(),
      outletToName: json['outlet_to_name']?.toString(),
      warehouseOutletFromName: json['warehouse_outlet_from_name']?.toString(),
      warehouseOutletToName: json['warehouse_outlet_to_name']?.toString(),
      approvalByName: json['approval_by_name']?.toString(),
      approvalAt: json['approval_at']?.toString(),
      approvalNotes: json['approval_notes']?.toString(),
      canApprove: json['can_approve'] == true,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AssetInventoryTransferItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvalFlows: (json['approval_flows'] as List<dynamic>?)
              ?.map((e) => AssetInventoryTransferApprovalFlow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString(),
    );
  }
}

class AssetInventoryTransferItem {
  final int id;
  final int itemId;
  final int? unitId;
  final double qty;
  final double qtySmall;
  final double qtyMedium;
  final double qtyLarge;
  final String? note;
  final String? itemName;
  final String? unitName;

  AssetInventoryTransferItem({
    required this.id,
    required this.itemId,
    this.unitId,
    this.qty = 0,
    this.qtySmall = 0,
    this.qtyMedium = 0,
    this.qtyLarge = 0,
    this.note,
    this.itemName,
    this.unitName,
  });

  factory AssetInventoryTransferItem.fromJson(Map<String, dynamic> json) {
    return AssetInventoryTransferItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      qtySmall: double.tryParse(json['qty_small']?.toString() ?? '0') ?? 0,
      qtyMedium: double.tryParse(json['qty_medium']?.toString() ?? '0') ?? 0,
      qtyLarge: double.tryParse(json['qty_large']?.toString() ?? '0') ?? 0,
      note: json['note']?.toString(),
      itemName: json['item_name']?.toString(),
      unitName: json['unit_name']?.toString(),
    );
  }
}

class AssetInventoryTransferApprovalFlow {
  final int id;
  final int approverId;
  final int approvalLevel;
  final String status;
  final String? approvedAt;
  final String? rejectedAt;
  final String? comments;
  final String? approverName;
  final String? approverJabatan;

  AssetInventoryTransferApprovalFlow({
    required this.id,
    required this.approverId,
    required this.approvalLevel,
    required this.status,
    this.approvedAt,
    this.rejectedAt,
    this.comments,
    this.approverName,
    this.approverJabatan,
  });

  factory AssetInventoryTransferApprovalFlow.fromJson(Map<String, dynamic> json) {
    return AssetInventoryTransferApprovalFlow(
      id: int.tryParse(json['id'].toString()) ?? 0,
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
