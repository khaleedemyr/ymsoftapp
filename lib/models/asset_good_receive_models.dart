class AssetGoodReceive {
  final int id;
  final String grNumber;
  final int poId;
  final int outletId;
  final int? warehouseOutletId;
  final String receiveDate;
  final int receivedBy;
  final String status;
  final String? notes;
  final String? poNumber;
  final String? outletName;
  final String? warehouseOutletName;
  final String? receivedByName;
  final String? supplierName;
  final double total;
  final List<AssetGoodReceiveItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssetGoodReceive({
    required this.id,
    required this.grNumber,
    required this.poId,
    required this.outletId,
    this.warehouseOutletId,
    required this.receiveDate,
    required this.receivedBy,
    required this.status,
    this.notes,
    this.poNumber,
    this.outletName,
    this.warehouseOutletName,
    this.receivedByName,
    this.supplierName,
    this.total = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssetGoodReceive.fromJson(Map<String, dynamic> json) {
    return AssetGoodReceive(
      id: int.tryParse(json['id'].toString()) ?? 0,
      grNumber: json['gr_number']?.toString() ?? '',
      poId: int.tryParse(json['po_id']?.toString() ?? '0') ?? 0,
      outletId: int.tryParse(json['outlet_id']?.toString() ?? '0') ?? 0,
      warehouseOutletId: json['warehouse_outlet_id'] != null
          ? int.tryParse(json['warehouse_outlet_id'].toString())
          : null,
      receiveDate: json['receive_date']?.toString() ?? '',
      receivedBy: int.tryParse(json['received_by']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'draft',
      notes: json['notes']?.toString(),
      poNumber: json['po_number']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  AssetGoodReceiveItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AssetGoodReceiveItem {
  final int id;
  final int assetGoodReceiveId;
  final int poItemId;
  final int itemId;
  final int unitId;
  final double qtyOrdered;
  final double qtyReceived;
  final double price;
  final double total;
  final String? notes;
  final String? itemName;
  final String? unitName;
  final String? poItemName;
  final double? poQuantity;
  final String? poUnit;

  AssetGoodReceiveItem({
    required this.id,
    required this.assetGoodReceiveId,
    required this.poItemId,
    required this.itemId,
    required this.unitId,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.price,
    required this.total,
    this.notes,
    this.itemName,
    this.unitName,
    this.poItemName,
    this.poQuantity,
    this.poUnit,
  });

  factory AssetGoodReceiveItem.fromJson(Map<String, dynamic> json) {
    return AssetGoodReceiveItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      assetGoodReceiveId:
          int.tryParse(json['asset_good_receive_id']?.toString() ?? '0') ?? 0,
      poItemId: int.tryParse(json['po_item_id']?.toString() ?? '0') ?? 0,
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      unitId: int.tryParse(json['unit_id']?.toString() ?? '0') ?? 0,
      qtyOrdered:
          double.tryParse(json['qty_ordered']?.toString() ?? '0') ?? 0.0,
      qtyReceived:
          double.tryParse(json['qty_received']?.toString() ?? '0') ?? 0.0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
      itemName: json['item_name']?.toString(),
      unitName: json['unit_name']?.toString(),
      poItemName: json['po_item_name']?.toString(),
      poQuantity: json['po_quantity'] != null
          ? double.tryParse(json['po_quantity'].toString())
          : null,
      poUnit: json['po_unit']?.toString(),
    );
  }
}

class AssetPOData {
  final Map<String, dynamic> po;
  final Map<String, dynamic>? supplier;
  final List<AssetPOItem> items;
  final List<Map<String, dynamic>> outlets;
  final List<Map<String, dynamic>> warehouseOutlets;
  final int userOutletId;

  AssetPOData({
    required this.po,
    this.supplier,
    required this.items,
    this.outlets = const [],
    this.warehouseOutlets = const [],
    this.userOutletId = 0,
  });

  factory AssetPOData.fromJson(Map<String, dynamic> json) {
    return AssetPOData(
      po: json['po'] as Map<String, dynamic>? ?? {},
      supplier: json['supplier'] as Map<String, dynamic>?,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  AssetPOItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      outlets: (json['outlets'] as List<dynamic>?)
              ?.map((o) => o as Map<String, dynamic>)
              .toList() ??
          [],
      warehouseOutlets: (json['warehouse_outlets'] as List<dynamic>?)
              ?.map((wo) => wo as Map<String, dynamic>)
              .toList() ??
          [],
      userOutletId:
          int.tryParse(json['user']?['id_outlet']?.toString() ?? '0') ?? 0,
    );
  }
}

class AssetPOItem {
  final int id;
  final String itemName;
  final double quantity;
  final String unit;
  final double price;
  final double? discountPercent;
  final double? discountAmount;
  final double total;
  final int? itemId;
  final String? resolvedItemName;
  final int? unitId;
  final double qtyAlreadyReceived;
  final double qtyRemaining;

  AssetPOItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.price,
    this.discountPercent,
    this.discountAmount,
    required this.total,
    this.itemId,
    this.resolvedItemName,
    this.unitId,
    this.qtyAlreadyReceived = 0,
    this.qtyRemaining = 0,
  });

  factory AssetPOItem.fromJson(Map<String, dynamic> json) {
    return AssetPOItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      discountPercent: json['discount_percent'] != null
          ? double.tryParse(json['discount_percent'].toString())
          : null,
      discountAmount: json['discount_amount'] != null
          ? double.tryParse(json['discount_amount'].toString())
          : null,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      itemId: json['item_id'] != null
          ? int.tryParse(json['item_id'].toString())
          : null,
      resolvedItemName: json['resolved_item_name']?.toString(),
      unitId: json['unit_id'] != null
          ? int.tryParse(json['unit_id'].toString())
          : null,
      qtyAlreadyReceived:
          double.tryParse(json['qty_already_received']?.toString() ?? '0') ??
              0,
      qtyRemaining:
          double.tryParse(json['qty_remaining']?.toString() ?? '0') ?? 0,
    );
  }
}
