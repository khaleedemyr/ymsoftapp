class OutletStockPositionItem {
  final int itemId;
  final String itemName;
  final int? categoryId;
  final String? categoryName;
  final int outletId;
  final String outletName;
  final int? warehouseOutletId;
  final String? warehouseOutletName;
  final double qtySmall;
  final double qtyMedium;
  final double qtyLarge;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;
  final String? updatedAt;

  OutletStockPositionItem({
    required this.itemId,
    required this.itemName,
    this.categoryId,
    this.categoryName,
    required this.outletId,
    required this.outletName,
    this.warehouseOutletId,
    this.warehouseOutletName,
    required this.qtySmall,
    required this.qtyMedium,
    required this.qtyLarge,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
    this.updatedAt,
  });

  factory OutletStockPositionItem.fromJson(Map<String, dynamic> json) {
    return OutletStockPositionItem(
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '-',
      categoryId: json['category_id'] != null ? int.tryParse(json['category_id'].toString()) : null,
      categoryName: json['category_name']?.toString(),
      outletId: int.tryParse(json['outlet_id'].toString()) ?? 0,
      outletName: json['outlet_name']?.toString() ?? '-',
      warehouseOutletId: json['warehouse_outlet_id'] != null
          ? int.tryParse(json['warehouse_outlet_id'].toString())
          : null,
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      qtySmall: double.tryParse(json['qty_small']?.toString() ?? '0') ?? 0,
      qtyMedium: double.tryParse(json['qty_medium']?.toString() ?? '0') ?? 0,
      qtyLarge: double.tryParse(json['qty_large']?.toString() ?? '0') ?? 0,
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get itemKey {
    final warehouseKey = warehouseOutletId?.toString() ?? 'null';
    return '$itemId-$outletId-$warehouseKey';
  }
}

class OutletStockCardEntry {
  final int id;
  final String? date;
  final String? itemName;
  final String? outletName;
  final String? warehouseOutletName;
  final double inQtySmall;
  final double inQtyMedium;
  final double inQtyLarge;
  final double outQtySmall;
  final double outQtyMedium;
  final double outQtyLarge;
  final double saldoQtySmall;
  final double saldoQtyMedium;
  final double saldoQtyLarge;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;
  final String? referenceType;
  final String? referenceId;
  final String? description;

  OutletStockCardEntry({
    required this.id,
    this.date,
    this.itemName,
    this.outletName,
    this.warehouseOutletName,
    required this.inQtySmall,
    required this.inQtyMedium,
    required this.inQtyLarge,
    required this.outQtySmall,
    required this.outQtyMedium,
    required this.outQtyLarge,
    required this.saldoQtySmall,
    required this.saldoQtyMedium,
    required this.saldoQtyLarge,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
    this.referenceType,
    this.referenceId,
    this.description,
  });

  factory OutletStockCardEntry.fromJson(Map<String, dynamic> json) {
    return OutletStockCardEntry(
      id: int.tryParse(json['id'].toString()) ?? 0,
      date: json['date']?.toString(),
      itemName: json['item_name']?.toString(),
      outletName: json['outlet_name']?.toString(),
      warehouseOutletName: json['warehouse_outlet_name']?.toString(),
      inQtySmall: double.tryParse(json['in_qty_small']?.toString() ?? '0') ?? 0,
      inQtyMedium: double.tryParse(json['in_qty_medium']?.toString() ?? '0') ?? 0,
      inQtyLarge: double.tryParse(json['in_qty_large']?.toString() ?? '0') ?? 0,
      outQtySmall: double.tryParse(json['out_qty_small']?.toString() ?? '0') ?? 0,
      outQtyMedium: double.tryParse(json['out_qty_medium']?.toString() ?? '0') ?? 0,
      outQtyLarge: double.tryParse(json['out_qty_large']?.toString() ?? '0') ?? 0,
      saldoQtySmall: double.tryParse(json['saldo_qty_small']?.toString() ?? '0') ?? 0,
      saldoQtyMedium: double.tryParse(json['saldo_qty_medium']?.toString() ?? '0') ?? 0,
      saldoQtyLarge: double.tryParse(json['saldo_qty_large']?.toString() ?? '0') ?? 0,
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class OutletStockCardSaldoAwal {
  final double small;
  final double medium;
  final double large;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;

  OutletStockCardSaldoAwal({
    required this.small,
    required this.medium,
    required this.large,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
  });

  factory OutletStockCardSaldoAwal.fromJson(Map<String, dynamic> json) {
    return OutletStockCardSaldoAwal(
      small: double.tryParse(json['small']?.toString() ?? '0') ?? 0,
      medium: double.tryParse(json['medium']?.toString() ?? '0') ?? 0,
      large: double.tryParse(json['large']?.toString() ?? '0') ?? 0,
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
    );
  }
}
