class CbrUserOption {
  final int id;
  final String name;
  final String? jabatan;
  final String? email;

  CbrUserOption({required this.id, required this.name, this.jabatan, this.email});

  factory CbrUserOption.fromJson(Map<String, dynamic> json) {
    return CbrUserOption(
      id: json['id'] as int? ?? int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['nama_lengkap']?.toString() ?? '',
      jabatan: json['jabatan']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'jabatan': jabatan, 'email': email};
}

class CbrReportListItem {
  final int id;
  final String number;
  final String? reportMonth;
  final int itemsCount;
  final String? creatorName;
  final int? createdBy;
  final bool canEdit;

  CbrReportListItem({
    required this.id,
    required this.number,
    required this.reportMonth,
    required this.itemsCount,
    this.creatorName,
    this.createdBy,
    this.canEdit = false,
  });

  factory CbrReportListItem.fromJson(Map<String, dynamic> json) {
    return CbrReportListItem(
      id: json['id'] as int? ?? 0,
      number: json['number']?.toString() ?? '',
      reportMonth: json['report_month']?.toString(),
      itemsCount: json['items_count'] as int? ?? 0,
      creatorName: json['creator_name']?.toString(),
      createdBy: json['created_by'] as int?,
      canEdit: json['can_edit'] == true,
    );
  }
}

class CbrReportItem {
  final int? id;
  final String brandRestaurantVisited;
  final String? location;
  final String? visitDate;
  final String? productBenchmark;
  final String? serviceBenchmark;
  final String? pricingBenchmark;
  final String? operationalBenchmark;
  final String? marketPositioningBenchmark;
  final String? summaryReport;
  final String? developmentActionPlan;

  CbrReportItem({
    this.id,
    required this.brandRestaurantVisited,
    this.location,
    this.visitDate,
    this.productBenchmark,
    this.serviceBenchmark,
    this.pricingBenchmark,
    this.operationalBenchmark,
    this.marketPositioningBenchmark,
    this.summaryReport,
    this.developmentActionPlan,
  });

  factory CbrReportItem.fromJson(Map<String, dynamic> json) {
    return CbrReportItem(
      id: json['id'] as int?,
      brandRestaurantVisited: json['brand_restaurant_visited']?.toString() ?? '',
      location: json['location']?.toString(),
      visitDate: json['visit_date']?.toString(),
      productBenchmark: json['product_benchmark']?.toString(),
      serviceBenchmark: json['service_benchmark']?.toString(),
      pricingBenchmark: json['pricing_benchmark']?.toString(),
      operationalBenchmark: json['operational_benchmark']?.toString(),
      marketPositioningBenchmark: json['market_positioning_benchmark']?.toString(),
      summaryReport: json['summary_report']?.toString(),
      developmentActionPlan: json['development_action_plan']?.toString(),
    );
  }
}
