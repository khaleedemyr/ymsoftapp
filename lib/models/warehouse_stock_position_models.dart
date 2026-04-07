class WarehouseStockPositionItem {
  final int itemId;
  final String itemName;
  final int? categoryId;
  final String? categoryName;
  final int warehouseId;
  final String warehouseName;
  final double qtySmall;
  final double qtyMedium;
  final double qtyLarge;
  final String? smallUnitName;
  final String? mediumUnitName;
  final String? largeUnitName;
  final String? updatedAt;

  WarehouseStockPositionItem({
    required this.itemId,
    required this.itemName,
    this.categoryId,
    this.categoryName,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtySmall,
    required this.qtyMedium,
    required this.qtyLarge,
    this.smallUnitName,
    this.mediumUnitName,
    this.largeUnitName,
    this.updatedAt,
  });

  factory WarehouseStockPositionItem.fromJson(Map<String, dynamic> json) {
    return WarehouseStockPositionItem(
      itemId: int.tryParse(json['item_id'].toString()) ?? 0,
      itemName: json['item_name']?.toString() ?? '-',
      categoryId: json['category_id'] != null ? int.tryParse(json['category_id'].toString()) : null,
      categoryName: json['category_name']?.toString(),
      warehouseId: int.tryParse(json['warehouse_id'].toString()) ?? 0,
      warehouseName: json['warehouse_name']?.toString() ?? '-',
      qtySmall: double.tryParse(json['qty_small']?.toString() ?? json['display_small']?.toString() ?? '0') ?? 0,
      qtyMedium: double.tryParse(json['qty_medium']?.toString() ?? json['display_medium']?.toString() ?? '0') ?? 0,
      qtyLarge: double.tryParse(json['qty_large']?.toString() ?? json['display_large']?.toString() ?? '0') ?? 0,
      smallUnitName: json['small_unit_name']?.toString(),
      mediumUnitName: json['medium_unit_name']?.toString(),
      largeUnitName: json['large_unit_name']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get itemKey => '$itemId-$warehouseId';
}
