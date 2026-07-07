class UpsellingListItem {
  final int id;
  final int outletId;
  final String? outletName;
  final int month;
  final String monthLabel;
  final int year;
  final String? createdAt;
  final String? createdByName;
  final double achievementPercent;
  final int itemsCount;

  UpsellingListItem({
    required this.id,
    required this.outletId,
    this.outletName,
    required this.month,
    required this.monthLabel,
    required this.year,
    this.createdAt,
    this.createdByName,
    required this.achievementPercent,
    required this.itemsCount,
  });

  factory UpsellingListItem.fromJson(Map<String, dynamic> json) {
    return UpsellingListItem(
      id: json['id'] as int? ?? 0,
      outletId: json['outlet_id'] as int? ?? 0,
      outletName: json['outlet_name']?.toString(),
      month: json['month'] as int? ?? 0,
      monthLabel: json['month_label']?.toString() ?? '',
      year: json['year'] as int? ?? 0,
      createdAt: json['created_at']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      achievementPercent: (json['achievement_percent'] as num?)?.toDouble() ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
    );
  }
}

class UpsellingItemLine {
  int itemId;
  String itemName;
  String categoryLabel;
  double averageCheck;
  int cover;
  double fbRevenue;
  String searchText;
  List<Map<String, dynamic>> suggestions;
  bool showSuggestions;

  UpsellingItemLine({
    this.itemId = 0,
    this.itemName = '',
    this.categoryLabel = '',
    this.averageCheck = 0,
    this.cover = 1,
    this.fbRevenue = 0,
    this.searchText = '',
    this.suggestions = const [],
    this.showSuggestions = false,
  });

  factory UpsellingItemLine.fromJson(Map<String, dynamic> json) {
    final line = UpsellingItemLine(
      itemId: json['item_id'] as int? ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      categoryLabel: json['category_label']?.toString() ?? '',
      averageCheck: (json['average_check'] as num?)?.toDouble() ?? 0,
      cover: json['cover'] as int? ?? 1,
      fbRevenue: (json['fb_revenue'] as num?)?.toDouble() ?? 0,
    );
    line.searchText = line.itemName;
    line.recalcFbRevenue();
    return line;
  }

  Map<String, dynamic> toPayload() => {
        'item_id': itemId,
        'item_name': itemName,
        'category_label': categoryLabel.isEmpty ? null : categoryLabel,
        'average_check': averageCheck,
        'cover': cover,
        'fb_revenue': fbRevenue.round(),
      };

  void recalcFbRevenue() {
    cover = cover < 1 ? 1 : cover;
    fbRevenue = (averageCheck * cover).roundToDouble();
  }
}

class UpsellingDetailRow {
  final int no;
  final int itemId;
  final String itemName;
  final String? categoryLabel;
  final Map<String, dynamic> target;
  final Map<String, dynamic> actual;
  final double achievementPercent;

  UpsellingDetailRow({
    required this.no,
    required this.itemId,
    required this.itemName,
    this.categoryLabel,
    required this.target,
    required this.actual,
    required this.achievementPercent,
  });

  factory UpsellingDetailRow.fromJson(Map<String, dynamic> json) {
    return UpsellingDetailRow(
      no: json['no'] as int? ?? 0,
      itemId: json['item_id'] as int? ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      categoryLabel: json['category_label']?.toString(),
      target: Map<String, dynamic>.from(json['target'] as Map? ?? {}),
      actual: Map<String, dynamic>.from(json['actual'] as Map? ?? {}),
      achievementPercent: (json['achievement_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}
