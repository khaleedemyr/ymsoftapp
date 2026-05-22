class AssetOwnerTransfer {
  final int id;
  final String transferNumber;
  final String transferDate;
  final String status;
  final String? notes;
  final String? creatorName;
  final String? ownerFromName;
  final String? ownerToName;
  final String? locationOutletName;
  final String? warehouseOutletName;
  final String? approvalByName;
  final String? approvalAt;
  final String? approvalNotes;
  final bool canApprove;
  final List<AssetOwnerTransferItem> items;
  final List<AssetOwnerTransferApprovalFlow> approvalFlows;
  final String? createdAt;

  AssetOwnerTransfer({
    required this.id,
    required this.transferNumber,
    required this.transferDate,
    required this.status,
    this.notes,
    this.creatorName,
    this.ownerFromName,
    this.ownerToName,
    this.locationOutletName,
    this.warehouseOutletName,
    this.approvalByName,
    this.approvalAt,
    this.approvalNotes,
    this.canApprove = false,
    this.items = const [],
    this.approvalFlows = const [],
    this.createdAt,
  });

  factory AssetOwnerTransfer.fromJson(Map<String, dynamic> json) {
    return AssetOwnerTransfer(
      id: int.tryParse(json['id'].toString()) ?? 0,
      transferNumber: json['transfer_number']?.toString() ?? '',
      transferDate: json['transfer_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      notes: json['notes']?.toString(),
      creatorName: json['creator_name']?.toString(),
      ownerFromName: json['owner_from_name']?.toString(),
      ownerToName: json['owner_to_name']?.toString(),
      locationOutletName: json['location_outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      approvalByName: json['approval_by_name']?.toString(),
      approvalAt: json['approval_at']?.toString(),
      approvalNotes: json['approval_notes']?.toString(),
      canApprove: json['can_approve'] == true,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AssetOwnerTransferItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvalFlows: (json['approval_flows'] as List<dynamic>?)
              ?.map((e) => AssetOwnerTransferApprovalFlow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString(),
    );
  }
}

class AssetOwnerTransferItem {
  final int id;
  final int itemId;
  final int? unitId;
  final double qty;
  final String? note;
  final String? itemName;
  final String? unitName;

  AssetOwnerTransferItem({
    required this.id,
    required this.itemId,
    this.unitId,
    this.qty = 0,
    this.note,
    this.itemName,
    this.unitName,
  });

  factory AssetOwnerTransferItem.fromJson(Map<String, dynamic> json) {
    return AssetOwnerTransferItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      note: json['note']?.toString(),
      itemName: json['item_name']?.toString(),
      unitName: json['unit_name']?.toString(),
    );
  }
}

class AssetOwnerTransferApprovalFlow {
  final int id;
  final int approverId;
  final int approvalLevel;
  final String status;
  final String? approvedAt;
  final String? rejectedAt;
  final String? comments;
  final String? approverName;
  final String? approverJabatan;

  AssetOwnerTransferApprovalFlow({
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

  factory AssetOwnerTransferApprovalFlow.fromJson(Map<String, dynamic> json) {
    return AssetOwnerTransferApprovalFlow(
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
