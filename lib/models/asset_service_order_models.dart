class AssetServiceOrder {
  final int id;
  final String number;
  final String date;
  final int? outletId;
  final int? warehouseOutletId;
  final int? supplierId;
  final String? description;
  final double estimatedCost;
  final double actualCost;
  final String? vendorInvoicePath;
  final String status;
  final String? creatorName;
  final String? ownerOutletName;
  final String? outletName;
  final String? warehouseOutletName;
  final String? supplierName;
  /// `internal` | `external` (default external jika API tidak kirim)
  final String serviceType;
  final String? sentDate;
  final String? returnDate;
  final bool canApprove;
  final bool canReceiveReturn;
  final bool canCreateNonFoodPayment;
  final Map<String, dynamic>? linkedNonFoodPayment;
  final List<AssetServiceOrderItem> items;
  final List<AssetServiceOrderApprovalFlow> approvalFlows;
  final String? createdAt;

  AssetServiceOrder({
    required this.id,
    required this.number,
    required this.date,
    this.outletId,
    this.warehouseOutletId,
    this.supplierId,
    this.description,
    this.estimatedCost = 0,
    this.actualCost = 0,
    this.vendorInvoicePath,
    required this.status,
    this.creatorName,
    this.ownerOutletName,
    this.outletName,
    this.warehouseOutletName,
    this.supplierName,
    this.serviceType = 'external',
    this.sentDate,
    this.returnDate,
    this.canApprove = false,
    this.canReceiveReturn = false,
    this.canCreateNonFoodPayment = false,
    this.linkedNonFoodPayment,
    this.items = const [],
    this.approvalFlows = const [],
    this.createdAt,
  });

  factory AssetServiceOrder.fromJson(Map<String, dynamic> json) {
    return AssetServiceOrder(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      outletId: json['outlet_id'] != null ? int.tryParse(json['outlet_id'].toString()) : null,
      warehouseOutletId: json['warehouse_outlet_id'] != null
          ? int.tryParse(json['warehouse_outlet_id'].toString())
          : null,
      supplierId: json['supplier_id'] != null ? int.tryParse(json['supplier_id'].toString()) : null,
      description: json['description']?.toString(),
      estimatedCost: double.tryParse(json['estimated_cost']?.toString() ?? '0') ?? 0,
      actualCost: double.tryParse(json['actual_cost']?.toString() ?? '0') ?? 0,
      vendorInvoicePath: json['vendor_invoice_path']?.toString(),
      status: json['status']?.toString() ?? 'waiting_approval',
      creatorName: json['creator_name']?.toString(),
      ownerOutletName: json['owner_outlet_name']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      serviceType: json['service_type']?.toString() ?? 'external',
      sentDate: json['sent_date']?.toString(),
      returnDate: json['return_date']?.toString(),
      canApprove: json['can_approve'] == true,
      canReceiveReturn: json['can_receive_return'] == true,
      canCreateNonFoodPayment: json['can_create_non_food_payment'] == true,
      linkedNonFoodPayment: json['linked_non_food_payment'] is Map
          ? Map<String, dynamic>.from(json['linked_non_food_payment'] as Map)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AssetServiceOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approvalFlows: (json['approval_flows'] as List<dynamic>?)
              ?.map((e) => AssetServiceOrderApprovalFlow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString(),
    );
  }
}

class AssetServiceOrderItem {
  final int id;
  final int? serviceOrderId;
  final int itemId;
  final double qtyOut;
  final double qtyReturned;
  final String? unit;
  final String? note;
  final String? returnDate;
  final String? returnNote;
  final String? itemName;

  AssetServiceOrderItem({
    required this.id,
    this.serviceOrderId,
    required this.itemId,
    this.qtyOut = 0,
    this.qtyReturned = 0,
    this.unit,
    this.note,
    this.returnDate,
    this.returnNote,
    this.itemName,
  });

  factory AssetServiceOrderItem.fromJson(Map<String, dynamic> json) {
    return AssetServiceOrderItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      serviceOrderId: json['service_order_id'] != null
          ? int.tryParse(json['service_order_id'].toString())
          : null,
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      qtyOut: double.tryParse(json['qty_out']?.toString() ?? '0') ?? 0,
      qtyReturned: double.tryParse(json['qty_returned']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString(),
      note: json['note']?.toString(),
      returnDate: json['return_date']?.toString(),
      returnNote: json['return_note']?.toString(),
      itemName: json['item_name']?.toString(),
    );
  }
}

class AssetServiceOrderApprovalFlow {
  final int id;
  final int? serviceOrderId;
  final int approverId;
  final int approvalLevel;
  final String status;
  final String? approvedAt;
  final String? rejectedAt;
  final String? comments;
  final String? approverName;
  final String? approverJabatan;

  AssetServiceOrderApprovalFlow({
    required this.id,
    this.serviceOrderId,
    required this.approverId,
    required this.approvalLevel,
    required this.status,
    this.approvedAt,
    this.rejectedAt,
    this.comments,
    this.approverName,
    this.approverJabatan,
  });

  factory AssetServiceOrderApprovalFlow.fromJson(Map<String, dynamic> json) {
    return AssetServiceOrderApprovalFlow(
      id: int.tryParse(json['id'].toString()) ?? 0,
      serviceOrderId: json['service_order_id'] != null
          ? int.tryParse(json['service_order_id'].toString())
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
