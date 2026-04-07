class FoodGoodReceive {
  final int id;
  final String grNumber;
  final String receiveDate;
  final int? poId;
  final String? poNumber;
  final int supplierId;
  final String supplierName;
  final int receivedBy;
  final String? receivedByName;
  final String? notes;
  final List<FoodGoodReceiveItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodGoodReceive({
    required this.id,
    required this.grNumber,
    required this.receiveDate,
    this.poId,
    this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.receivedBy,
    this.receivedByName,
    this.notes,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodGoodReceive.fromJson(Map<String, dynamic> json) {
    return FoodGoodReceive(
      id: int.tryParse(json['id'].toString()) ?? 0,
      grNumber: json['gr_number']?.toString() ?? '',
      receiveDate: json['receive_date']?.toString() ?? '',
      poId: json['po_id'] != null ? int.tryParse(json['po_id'].toString()) : null,
      poNumber: json['po_number']?.toString(),
      supplierId: int.tryParse(json['supplier_id'].toString()) ?? 0,
      supplierName: json['supplier_name']?.toString() ?? json['supplier']?['name']?.toString() ?? '',
      receivedBy: int.tryParse(json['received_by'].toString()) ?? 0,
      receivedByName: json['received_by_name']?.toString(),
      notes: json['notes']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => FoodGoodReceiveItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gr_number': grNumber,
      'receive_date': receiveDate,
      'po_id': poId,
      'po_number': poNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'received_by': receivedBy,
      'received_by_name': receivedByName,
      'notes': notes,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class FoodGoodReceiveItem {
  final int id;
  final int goodReceiveId;
  final int itemId;
  final String itemName;
  final double qtyOrdered;
  final double qtyReceived;
  final int unitId;
  final String unitName;
  final String? warehouseDivisionName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodGoodReceiveItem({
    required this.id,
    required this.goodReceiveId,
    required this.itemId,
    required this.itemName,
    required this.qtyOrdered,
    required this.qtyReceived,
    required this.unitId,
    required this.unitName,
    this.warehouseDivisionName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodGoodReceiveItem.fromJson(Map<String, dynamic> json) {
    return FoodGoodReceiveItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      goodReceiveId: int.tryParse(json['good_receive_id']?.toString() ?? '0') ?? 0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      qtyOrdered: double.tryParse(json['qty_ordered']?.toString() ?? '0') ?? 0.0,
      qtyReceived: double.tryParse(json['qty_received']?.toString() ?? '0') ?? 0.0,
      unitId: int.tryParse(json['unit_id'].toString()) ?? 0,
      unitName: json['unit_name']?.toString() ?? '',
      warehouseDivisionName: json['warehouse_division_name']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'good_receive_id': goodReceiveId,
      'item_id': itemId,
      'item_name': itemName,
      'qty_ordered': qtyOrdered,
      'qty_received': qtyReceived,
      'unit_id': unitId,
      'unit_name': unitName,
      'warehouse_division_name': warehouseDivisionName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PurchaseOrderFood {
  final int id;
  final String number;
  final int supplierId;
  final String supplierName;
  final String orderDate;
  final String? deliveryDate;
  final String? sourceType;
  final List<POFoodItem> items;

  PurchaseOrderFood({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.supplierName,
    required this.orderDate,
    this.deliveryDate,
    this.sourceType,
    required this.items,
  });

  factory PurchaseOrderFood.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderFood(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '',
      supplierId: int.tryParse(json['supplier_id'].toString()) ?? 0,
      supplierName: json['supplier_name']?.toString() ?? '',
      orderDate: json['order_date']?.toString() ?? '',
      deliveryDate: json['delivery_date']?.toString(),
      sourceType: json['source_type']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => POFoodItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class POFoodItem {
  final int id;
  final int purchaseOrderFoodId;
  final int itemId;
  final String itemName;
  final double qty;
  final int unitId;
  final String unitName;
  final String? warehouseDivisionName;
  final double? price;

  POFoodItem({
    required this.id,
    required this.purchaseOrderFoodId,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unitId,
    required this.unitName,
    this.warehouseDivisionName,
    this.price,
  });

  factory POFoodItem.fromJson(Map<String, dynamic> json) {
    return POFoodItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      purchaseOrderFoodId: int.tryParse(json['purchase_order_food_id']?.toString() ?? '0') ?? 0,
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      unitId: int.tryParse(json['unit_id'].toString()) ?? 0,
      unitName: json['unit_name']?.toString() ?? '',
      warehouseDivisionName: json['warehouse_division_name']?.toString(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_order_food_id': purchaseOrderFoodId,
      'item_id': itemId,
      'item_name': itemName,
      'qty': qty,
      'unit_id': unitId,
      'unit_name': unitName,
      'warehouse_division_name': warehouseDivisionName,
      'price': price,
    };
  }
}
