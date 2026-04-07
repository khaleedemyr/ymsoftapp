class CategoryCostHeader {
  final int id;
  final String reference;
  final String date;
  final String outletName;
  final double totalCost;

  CategoryCostHeader({
    required this.id,
    required this.reference,
    required this.date,
    required this.outletName,
    required this.totalCost,
  });

  factory CategoryCostHeader.fromJson(Map<String, dynamic> json) {
    return CategoryCostHeader(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      date: json['date'] ?? '',
      outletName: json['outlet_name'] ?? json['outlet'] ?? '',
      totalCost: (json['total_cost'] != null) ? (json['total_cost'] as num).toDouble() : 0.0,
    );
  }
}

class CategoryCostItem {
  final int id;
  final String name;
  final String unit;
  final double qty;
  final double cost;

  CategoryCostItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    required this.cost,
  });

  factory CategoryCostItem.fromJson(Map<String, dynamic> json) {
    return CategoryCostItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['item_name'] ?? '',
      unit: json['unit'] ?? '',
      qty: (json['qty'] != null) ? (json['qty'] as num).toDouble() : 0.0,
      cost: (json['cost'] != null) ? (json['cost'] as num).toDouble() : 0.0,
    );
  }
}
