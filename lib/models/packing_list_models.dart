class PackingList {
  final int id;
  final String packingNumber;
  final DateTime createdAt;
  final String? status;
  final int? foodFloorOrderId;
  final int? warehouseDivisionId;
  final String? reason;
  final int? createdBy;
  
  // Relations
  final FloorOrder? floorOrder;
  final WarehouseDivision? warehouseDivision;
  final User? creator;
  final List<PackingListItem> items;

  PackingList({
    required this.id,
    required this.packingNumber,
    required this.createdAt,
    this.status,
    this.foodFloorOrderId,
    this.warehouseDivisionId,
    this.reason,
    this.createdBy,
    this.floorOrder,
    this.warehouseDivision,
    this.creator,
    this.items = const [],
  });

  factory PackingList.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return PackingList(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      packingNumber: json['packing_number']?.toString() ?? '',
      createdAt: json['created_at'] != null 
          ? (json['created_at'] is DateTime 
              ? json['created_at'] 
              : DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: json['status']?.toString(),
      foodFloorOrderId: parseInt(json['food_floor_order_id']),
      warehouseDivisionId: parseInt(json['warehouse_division_id']),
      reason: json['reason']?.toString(),
      createdBy: parseInt(json['created_by']),
      floorOrder: json['floor_order'] != null 
          ? FloorOrder.fromJson(json['floor_order']) 
          : null,
      warehouseDivision: json['warehouse_division'] != null
          ? WarehouseDivision.fromJson(json['warehouse_division'])
          : null,
      creator: json['creator'] != null
          ? User.fromJson(json['creator'])
          : null,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => PackingListItem.fromJson(i)).toList()
          : [],
    );
  }
}

class PackingListItem {
  final int id;
  final int? packingListId;
  final int? foodFloorOrderItemId;
  final double qty;
  final String unit;
  final String? source;
  final String? reason;
  
  // Relations
  final FloorOrderItem? floorOrderItem;

  PackingListItem({
    required this.id,
    this.packingListId,
    this.foodFloorOrderItemId,
    required this.qty,
    required this.unit,
    this.source,
    this.reason,
    this.floorOrderItem,
  });

  factory PackingListItem.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return PackingListItem(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      packingListId: parseInt(json['packing_list_id']),
      foodFloorOrderItemId: parseInt(json['food_floor_order_item_id']),
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : 0.0,
      unit: json['unit']?.toString() ?? '',
      source: json['source']?.toString(),
      reason: json['reason']?.toString(),
      floorOrderItem: json['floor_order_item'] != null
          ? FloorOrderItem.fromJson(json['floor_order_item'])
          : null,
    );
  }
}

class FloorOrder {
  final int id;
  final String? orderNumber;
  final DateTime? tanggal;
  final DateTime? arrivalDate;
  final String? status;
  final String? foMode;
  final int? idOutlet;
  final int? userId;
  
  // Relations
  final Outlet? outlet;
  final User? requester;
  final WarehouseOutlet? warehouseOutlet;
  final List<WarehouseDivision>? warehouseDivisions;
  final List<FloorOrderItem>? items;

  FloorOrder({
    required this.id,
    this.orderNumber,
    this.tanggal,
    this.arrivalDate,
    this.status,
    this.foMode,
    this.idOutlet,
    this.userId,
    this.outlet,
    this.requester,
    this.warehouseOutlet,
    this.warehouseDivisions,
    this.items,
  });

  factory FloorOrder.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return FloorOrder(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      orderNumber: json['order_number']?.toString(),
      tanggal: json['tanggal'] != null 
          ? (json['tanggal'] is DateTime 
              ? json['tanggal'] 
              : DateTime.tryParse(json['tanggal'].toString()))
          : null,
      arrivalDate: json['arrival_date'] != null 
          ? (json['arrival_date'] is DateTime 
              ? json['arrival_date'] 
              : DateTime.tryParse(json['arrival_date'].toString()))
          : null,
      status: json['status']?.toString(),
      foMode: json['fo_mode']?.toString(),
      idOutlet: parseInt(json['id_outlet']),
      userId: parseInt(json['user_id']),
      outlet: json['outlet'] != null ? Outlet.fromJson(json['outlet']) : null,
      requester: json['requester'] != null || json['user'] != null
          ? User.fromJson(json['requester'] ?? json['user'])
          : null,
      warehouseOutlet: json['warehouse_outlet'] != null
          ? WarehouseOutlet.fromJson(json['warehouse_outlet'])
          : null,
      warehouseDivisions: json['warehouse_divisions'] != null
          ? (json['warehouse_divisions'] as List).map((d) => WarehouseDivision.fromJson(d)).toList()
          : null,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => FloorOrderItem.fromJson(i)).toList()
          : null,
    );
  }
}

class FloorOrderItem {
  final int id;
  final int? floorOrderId;
  final int? itemId;
  final double qty;
  final String unit;
  
  // Relations
  final Item? item;

  FloorOrderItem({
    required this.id,
    this.floorOrderId,
    this.itemId,
    required this.qty,
    required this.unit,
    this.item,
  });

  factory FloorOrderItem.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return FloorOrderItem(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      floorOrderId: parseInt(json['floor_order_id']),
      itemId: parseInt(json['item_id']),
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : 0.0,
      unit: json['unit']?.toString() ?? '',
      item: json['item'] != null ? Item.fromJson(json['item']) : null,
    );
  }
}

class WarehouseDivision {
  final int id;
  final String name;
  final int? warehouseId;

  WarehouseDivision({
    required this.id,
    required this.name,
    this.warehouseId,
  });

  factory WarehouseDivision.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return WarehouseDivision(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      name: json['name']?.toString() ?? '',
      warehouseId: parseInt(json['warehouse_id']),
    );
  }
}

class WarehouseOutlet {
  final int id;
  final String name;

  WarehouseOutlet({
    required this.id,
    required this.name,
  });

  factory WarehouseOutlet.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return WarehouseOutlet(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Outlet {
  final int id;
  final String namaOutlet;

  Outlet({
    required this.id,
    required this.namaOutlet,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return Outlet(
      id: parseId(json['id_outlet'] ?? json['id']),
      namaOutlet: json['nama_outlet']?.toString() ?? '',
    );
  }
}

class User {
  final int id;
  final String namaLengkap;

  User({
    required this.id,
    required this.namaLengkap,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return User(
      id: parseId(json['id']),
      namaLengkap: json['nama_lengkap']?.toString() ?? '',
    );
  }
}

class Item {
  final int id;
  final String name;
  final int? warehouseDivisionId;
  final Category? category;
  final Unit? smallUnit;
  final Unit? mediumUnit;
  final Unit? largeUnit;

  Item({
    required this.id,
    required this.name,
    this.warehouseDivisionId,
    this.category,
    this.smallUnit,
    this.mediumUnit,
    this.largeUnit,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    return Item(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      name: json['name']?.toString() ?? '',
      warehouseDivisionId: parseInt(json['warehouse_division_id']),
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      smallUnit: json['small_unit'] != null ? Unit.fromJson(json['small_unit']) : null,
      mediumUnit: json['medium_unit'] != null ? Unit.fromJson(json['medium_unit']) : null,
      largeUnit: json['large_unit'] != null ? Unit.fromJson(json['large_unit']) : null,
    );
  }
}

class Category {
  final int id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return Category(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Unit {
  final int id;
  final String name;

  Unit({
    required this.id,
    required this.name,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return Unit(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

// Model untuk available item dengan stock
class AvailableItem {
  final int id;
  final int? itemId;
  final int? floorOrderId;
  final double qty;
  final double? qtyOrder;
  final String unit;
  final double? stock;
  final Item? item;
  final bool checked;
  final double? inputQty;
  final String source;
  final String? reason;

  AvailableItem({
    required this.id,
    this.itemId,
    this.floorOrderId,
    required this.qty,
    this.qtyOrder,
    required this.unit,
    this.stock,
    this.item,
    this.checked = true,
    this.inputQty,
    this.source = 'warehouse',
    this.reason,
  });

  factory AvailableItem.fromJson(Map<String, dynamic> json) {
    // Helper function untuk convert ke int?
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        if (value.isEmpty) return null;
        return int.tryParse(value);
      }
      if (value is num) return value.toInt();
      return null;
    }

    // Helper function untuk convert ke double?
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        if (value.isEmpty) return null;
        return double.tryParse(value);
      }
      if (value is num) return value.toDouble();
      return null;
    }

    return AvailableItem(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) ?? 0 : 0),
      itemId: parseInt(json['item_id']),
      floorOrderId: parseInt(json['floor_order_id']),
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : 0.0,
      qtyOrder: parseDouble(json['qty_order']),
      unit: json['unit']?.toString() ?? '',
      stock: parseDouble(json['stock']),
      item: json['item'] != null ? Item.fromJson(json['item']) : null,
      checked: json['checked'] ?? true,
      inputQty: parseDouble(json['input_qty']),
      source: json['source']?.toString() ?? 'warehouse',
      reason: json['reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_floor_order_item_id': id,
      'qty': inputQty ?? qty,
      'unit': unit,
      'source': source,
      'reason': reason,
    };
  }
}

