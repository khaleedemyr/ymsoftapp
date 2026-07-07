class AssetDisposal {
  final int id;
  final String number;
  final String date;
  final String type;
  final String description;
  final String? buyerName;
  final String? buyerContact;
  final double totalSalePrice;
  final String status;
  final String? ownerOutletName;
  final String? outletName;
  final String? warehouseOutletName;
  final String? creatorName;
  final bool? canApprove;
  final List<AssetDisposalItem>? items;
  final List<AssetDisposalPhoto>? photos;
  final List<AssetDisposalApprovalFlow>? approvalFlows;

  AssetDisposal({
    required this.id,
    required this.number,
    required this.date,
    required this.type,
    required this.description,
    this.buyerName,
    this.buyerContact,
    this.totalSalePrice = 0,
    required this.status,
    this.ownerOutletName,
    this.outletName,
    this.warehouseOutletName,
    this.creatorName,
    this.canApprove,
    this.items,
    this.photos,
    this.approvalFlows,
  });

  factory AssetDisposal.fromJson(Map<String, dynamic> json) {
    return AssetDisposal(
      id: json['id'] ?? 0,
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      type: json['type'] ?? 'discard',
      description: json['description'] ?? '',
      buyerName: json['buyer_name'],
      buyerContact: json['buyer_contact'],
      totalSalePrice: double.tryParse(json['total_sale_price']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? '',
      ownerOutletName: json['owner_outlet_name'],
      outletName: json['outlet_name'],
      warehouseOutletName: json['warehouse_outlet_name'],
      creatorName: json['creator_name'],
      canApprove: json['can_approve'],
      items: json['items'] != null
          ? (json['items'] as List).map((e) => AssetDisposalItem.fromJson(e)).toList()
          : null,
      photos: json['photos'] != null
          ? (json['photos'] as List).map((e) => AssetDisposalPhoto.fromJson(e)).toList()
          : null,
      approvalFlows: json['approval_flows'] != null
          ? (json['approval_flows'] as List).map((e) => AssetDisposalApprovalFlow.fromJson(e)).toList()
          : null,
    );
  }
}

class AssetDisposalItem {
  final int id;
  final int? itemId;
  final String itemName;
  final String unit;
  final double qty;
  final double salePrice;
  final String? note;

  AssetDisposalItem({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.unit,
    required this.qty,
    this.salePrice = 0,
    this.note,
  });

  factory AssetDisposalItem.fromJson(Map<String, dynamic> json) {
    return AssetDisposalItem(
      id: json['id'] ?? 0,
      itemId: json['item_id'],
      itemName: json['item_name'] ?? '-',
      unit: json['unit'] ?? '-',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      salePrice: double.tryParse(json['sale_price']?.toString() ?? '0') ?? 0,
      note: json['note'],
    );
  }
}

class AssetDisposalPhoto {
  final int id;
  final String path;
  final String url;
  final String? caption;

  AssetDisposalPhoto({
    required this.id,
    required this.path,
    required this.url,
    this.caption,
  });

  factory AssetDisposalPhoto.fromJson(Map<String, dynamic> json) {
    return AssetDisposalPhoto(
      id: json['id'] ?? 0,
      path: json['path'] ?? '',
      url: json['url'] ?? '',
      caption: json['caption'],
    );
  }
}

class AssetDisposalApprovalFlow {
  final int id;
  final int? approverId;
  final String? approverName;
  final String? approverJabatan;
  final int approvalLevel;
  final String status;
  final String? approvedAt;
  final String? rejectedAt;
  final String? comments;

  AssetDisposalApprovalFlow({
    required this.id,
    this.approverId,
    this.approverName,
    this.approverJabatan,
    required this.approvalLevel,
    required this.status,
    this.approvedAt,
    this.rejectedAt,
    this.comments,
  });

  factory AssetDisposalApprovalFlow.fromJson(Map<String, dynamic> json) {
    return AssetDisposalApprovalFlow(
      id: json['id'] ?? 0,
      approverId: json['approver_id'],
      approverName: json['approver_name'],
      approverJabatan: json['approver_jabatan'],
      approvalLevel: json['approval_level'] ?? 1,
      status: json['status'] ?? 'PENDING',
      approvedAt: json['approved_at']?.toString(),
      rejectedAt: json['rejected_at']?.toString(),
      comments: json['comments'],
    );
  }
}
