class OutletStockAdjustmentListItem {
  final int id;
  final String number;
  final String date;
  final String? outletName;
  final String? warehouseOutletName;
  final String? type;
  final String? status;
  final String? creatorName;
  final String? creatorAvatar;

  OutletStockAdjustmentListItem({
    required this.id,
    required this.number,
    required this.date,
    this.outletName,
    this.warehouseOutletName,
    this.type,
    this.status,
    this.creatorName,
    this.creatorAvatar,
  });

  factory OutletStockAdjustmentListItem.fromJson(Map<String, dynamic> json) {
    return OutletStockAdjustmentListItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '-',
      date: json['date']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? json['nama_outlet']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      creatorName: json['creator_name']?.toString() ?? json['creator_nama_lengkap']?.toString(),
      creatorAvatar: json['creator_avatar']?.toString(),
    );
  }
}

class OutletStockAdjustmentDetail {
  final int id;
  final String number;
  final String date;
  final String? outletName;
  final String? warehouseOutletName;
  final String? type;
  final String? status;
  final String? reason;
  final String? creatorName;
  final String? creatorAvatar;
  final String? createdAt;
  final List<OutletStockAdjustmentItem> items;
  final List<OutletStockAdjustmentApprovalFlow> approvalFlows;

  OutletStockAdjustmentDetail({
    required this.id,
    required this.number,
    required this.date,
    this.outletName,
    this.warehouseOutletName,
    this.type,
    this.status,
    this.reason,
    this.creatorName,
    this.creatorAvatar,
    this.createdAt,
    required this.items,
    required this.approvalFlows,
  });

  factory OutletStockAdjustmentDetail.fromJson(Map<String, dynamic> json) {
    final adjustment = json['adjustment'] as Map<String, dynamic>? ?? json;
    final itemsRaw = (json['items'] ?? adjustment['items']) as List<dynamic>? ?? [];
    final flowsRaw = (json['approval_flows'] ?? adjustment['approval_flows']) as List<dynamic>? ?? [];

    return OutletStockAdjustmentDetail(
      id: int.tryParse(adjustment['id'].toString()) ?? 0,
      number: adjustment['number']?.toString() ?? '-',
      date: adjustment['date']?.toString() ?? '',
      outletName: adjustment['outlet_name']?.toString() ?? adjustment['nama_outlet']?.toString(),
      warehouseOutletName: adjustment['warehouse_outlet_name']?.toString(),
      type: adjustment['type']?.toString(),
      status: adjustment['status']?.toString(),
      reason: adjustment['reason']?.toString(),
      creatorName: adjustment['creator_name']?.toString() ?? adjustment['creator_nama_lengkap']?.toString(),
      creatorAvatar: adjustment['creator_avatar']?.toString(),
      createdAt: adjustment['created_at']?.toString(),
      items: itemsRaw
          .map((item) => OutletStockAdjustmentItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      approvalFlows: flowsRaw
          .map((flow) => OutletStockAdjustmentApprovalFlow.fromJson(flow as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutletStockAdjustmentItem {
  final int id;
  final int itemId;
  final String itemName;
  final double qty;
  final String? unit;
  final String? note;

  OutletStockAdjustmentItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qty,
    this.unit,
    this.note,
  });

  factory OutletStockAdjustmentItem.fromJson(Map<String, dynamic> json) {
    return OutletStockAdjustmentItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? json['item']?['name']?.toString() ?? '-',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class OutletStockAdjustmentApprovalFlow {
  final int id;
  final int? approvalLevel;
  final String? approverName;
  final String? approverTitle;
  final String? status;
  final String? approvedAt;
  final String? comments;

  OutletStockAdjustmentApprovalFlow({
    required this.id,
    this.approvalLevel,
    this.approverName,
    this.approverTitle,
    this.status,
    this.approvedAt,
    this.comments,
  });

  factory OutletStockAdjustmentApprovalFlow.fromJson(Map<String, dynamic> json) {
    return OutletStockAdjustmentApprovalFlow(
      id: int.tryParse(json['id'].toString()) ?? 0,
      approvalLevel: json['approval_level'] != null
          ? int.tryParse(json['approval_level'].toString())
          : null,
      approverName: json['nama_lengkap']?.toString() ?? json['approver_name']?.toString(),
      approverTitle: json['nama_jabatan']?.toString() ?? json['jabatan']?.toString(),
      status: json['status']?.toString(),
      approvedAt: json['approved_at']?.toString(),
      comments: json['comments']?.toString(),
    );
  }
}

class OutletStockAdjustmentApprover {
  final int id;
  final String name;
  final String? email;
  final String? jabatan;

  OutletStockAdjustmentApprover({
    required this.id,
    required this.name,
    this.email,
    this.jabatan,
  });

  factory OutletStockAdjustmentApprover.fromJson(Map<String, dynamic> json) {
    return OutletStockAdjustmentApprover(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? json['nama_lengkap']?.toString() ?? '-',
      email: json['email']?.toString(),
      jabatan: json['jabatan']?.toString() ?? json['nama_jabatan']?.toString(),
    );
  }
}
