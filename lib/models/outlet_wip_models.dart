/// Model for list item (header row from apiIndex).
class OutletWIPListItem {
  final int id;
  final String? number;
  final String? productionDate;
  final String? batchNumber;
  final int? outletId;
  final int? warehouseOutletId;
  final String? notes;
  final String? status;
  final int? createdBy;
  final String? createdAt;
  final String? outletName;
  final String? warehouseOutletName;
  final String? createdByName;
  final String? createdByAvatar;
  final String? sourceType;

  OutletWIPListItem({
    required this.id,
    this.number,
    this.productionDate,
    this.batchNumber,
    this.outletId,
    this.warehouseOutletId,
    this.notes,
    this.status,
    this.createdBy,
    this.createdAt,
    this.outletName,
    this.warehouseOutletName,
    this.createdByName,
    this.createdByAvatar,
    this.sourceType,
  });

  factory OutletWIPListItem.fromJson(Map<String, dynamic> json) {
    return OutletWIPListItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString(),
      productionDate: json['production_date']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      outletId: int.tryParse(json['outlet_id'].toString()),
      warehouseOutletId: int.tryParse(json['warehouse_outlet_id'].toString()),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      createdBy: int.tryParse(json['created_by'].toString()),
      createdAt: json['created_at']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      createdByAvatar: json['user_avatar']?.toString(),
      sourceType: json['source_type']?.toString(),
    );
  }
}

/// One production line (item + qty) in header detail or form.
class OutletWIPProductionLine {
  final int? id;
  final int? headerId;
  final int itemId;
  final double qty;
  final double qtyJadi;
  final int unitId;
  final String? itemName;
  final String? unitName;

  OutletWIPProductionLine({
    this.id,
    this.headerId,
    required this.itemId,
    required this.qty,
    required this.qtyJadi,
    required this.unitId,
    this.itemName,
    this.unitName,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (headerId != null) 'header_id': headerId,
        'item_id': itemId,
        'qty': qty,
        'qty_jadi': qtyJadi,
        'unit_id': unitId,
      };

  factory OutletWIPProductionLine.fromJson(Map<String, dynamic> json) {
    return OutletWIPProductionLine(
      id: int.tryParse(json['id'].toString()),
      headerId: int.tryParse(json['header_id']?.toString() ?? ''),
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      qty: (double.tryParse(json['qty'].toString()) ?? 0).toDouble(),
      qtyJadi: (double.tryParse(json['qty_jadi'].toString()) ?? 0).toDouble(),
      unitId: int.tryParse(json['unit_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString(),
      unitName: json['unit_name']?.toString(),
    );
  }
}

/// Create form: item option (WIP item for dropdown).
class OutletWIPItemOption {
  final int id;
  final String name;
  final int? smallUnitId;
  final int? mediumUnitId;
  final int? largeUnitId;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;

  OutletWIPItemOption({
    required this.id,
    required this.name,
    this.smallUnitId,
    this.mediumUnitId,
    this.largeUnitId,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
  });

  factory OutletWIPItemOption.fromJson(Map<String, dynamic> json) {
    return OutletWIPItemOption(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      smallUnitId: int.tryParse(json['small_unit_id']?.toString() ?? ''),
      mediumUnitId: int.tryParse(json['medium_unit_id']?.toString() ?? ''),
      largeUnitId: int.tryParse(json['large_unit_id']?.toString() ?? ''),
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
    );
  }
}

/// Warehouse outlet option.
class OutletWIPWarehouseOption {
  final int id;
  final String name;
  final int outletId;

  OutletWIPWarehouseOption({
    required this.id,
    required this.name,
    required this.outletId,
  });

  factory OutletWIPWarehouseOption.fromJson(Map<String, dynamic> json) {
    return OutletWIPWarehouseOption(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      outletId: int.tryParse(json['outlet_id'].toString()) ?? 0,
    );
  }
}

/// Outlet option (for admin).
class OutletWIPOutletOption {
  final int id;
  final String name;

  OutletWIPOutletOption({
    required this.id,
    required this.name,
  });

  factory OutletWIPOutletOption.fromJson(Map<String, dynamic> json) {
    return OutletWIPOutletOption(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}
