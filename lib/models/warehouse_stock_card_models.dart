/// Model untuk satu baris kartu stok gudang (warehouse stock card entry).
class WarehouseStockCardEntry {
  final int id;
  final String? date;
  final String? itemName;
  final String? warehouseName;
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

  WarehouseStockCardEntry({
    required this.id,
    this.date,
    this.itemName,
    this.warehouseName,
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

  factory WarehouseStockCardEntry.fromJson(Map<String, dynamic> json) {
    return WarehouseStockCardEntry(
      id: int.tryParse(json['id'].toString()) ?? 0,
      date: json['date']?.toString(),
      itemName: json['item_name']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
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

class WarehouseStockCardSaldoAwal {
  final double small;
  final double medium;
  final double large;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;

  WarehouseStockCardSaldoAwal({
    required this.small,
    required this.medium,
    required this.large,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
  });

  factory WarehouseStockCardSaldoAwal.fromJson(Map<String, dynamic> json) {
    return WarehouseStockCardSaldoAwal(
      small: double.tryParse(json['small']?.toString() ?? '0') ?? 0,
      medium: double.tryParse(json['medium']?.toString() ?? '0') ?? 0,
      large: double.tryParse(json['large']?.toString() ?? '0') ?? 0,
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
    );
  }
}
