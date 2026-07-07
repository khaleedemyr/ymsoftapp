class NpdPurposeOption {
  final String value;
  final String label;

  NpdPurposeOption({required this.value, required this.label});

  factory NpdPurposeOption.fromJson(Map<String, dynamic> json) {
    return NpdPurposeOption(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class NpdUserOption {
  final int id;
  final String name;
  final String? jabatan;
  final String? email;

  NpdUserOption({
    required this.id,
    required this.name,
    this.jabatan,
    this.email,
  });

  factory NpdUserOption.fromJson(Map<String, dynamic> json) {
    return NpdUserOption(
      id: json['id'] as int? ?? int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['nama_lengkap']?.toString() ?? '',
      jabatan: json['jabatan']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'jabatan': jabatan,
        'email': email,
      };
}

class NpdReportListItem {
  final int id;
  final String number;
  final String? reportMonth;
  final String outletName;
  final String status;
  final int itemsCount;
  final String? creatorName;
  final int? createdBy;

  NpdReportListItem({
    required this.id,
    required this.number,
    required this.reportMonth,
    required this.outletName,
    required this.status,
    required this.itemsCount,
    this.creatorName,
    this.createdBy,
  });

  factory NpdReportListItem.fromJson(Map<String, dynamic> json) {
    return NpdReportListItem(
      id: json['id'] as int? ?? 0,
      number: json['number']?.toString() ?? '',
      reportMonth: json['report_month']?.toString(),
      outletName: json['outlet_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      itemsCount: json['items_count'] as int? ?? 0,
      creatorName: json['creator_name']?.toString(),
      createdBy: json['created_by'] as int?,
    );
  }
}

class NpdReportItem {
  final int? id;
  final String productName;
  final int? categoryId;
  final String? category;
  final String? developmentDate;
  final String purpose;
  final String? proposedLaunchDate;
  final List<Map<String, dynamic>> launchOutlets;
  final List<NpdUserOption> pics;
  final double fbCost;
  final double sellingPrice;

  NpdReportItem({
    this.id,
    required this.productName,
    this.categoryId,
    this.category,
    this.developmentDate,
    required this.purpose,
    this.proposedLaunchDate,
    required this.launchOutlets,
    required this.pics,
    required this.fbCost,
    required this.sellingPrice,
  });

  factory NpdReportItem.fromJson(Map<String, dynamic> json) {
    final launchRaw = json['proposed_launch_area_outlet'];
    final picsRaw = json['pics'];
    return NpdReportItem(
      id: json['id'] as int?,
      productName: json['product_name']?.toString() ?? '',
      categoryId: json['category_id'] as int?,
      category: json['category']?.toString(),
      developmentDate: json['development_date']?.toString(),
      purpose: json['purpose']?.toString() ?? 'new_product',
      proposedLaunchDate: json['proposed_launch_date']?.toString(),
      launchOutlets: launchRaw is List
          ? launchRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [],
      pics: picsRaw is List
          ? picsRaw.map((e) => NpdUserOption.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [],
      fbCost: (json['fb_cost'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toPayload() => {
        'product_name': productName,
        'category_id': categoryId,
        'development_date': developmentDate?.isNotEmpty == true ? developmentDate : null,
        'purpose': purpose,
        'proposed_launch_date': proposedLaunchDate?.isNotEmpty == true ? proposedLaunchDate : null,
        'proposed_launch_outlet_ids': launchOutlets
            .map((e) => e['id'] ?? e['id_outlet'])
            .where((e) => e != null)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList(),
        'pic_user_ids': pics.map((p) => p.id).toList(),
        'fb_cost': fbCost,
        'selling_price': sellingPrice,
      };
}

class NpdApprovalFlowItem {
  final int id;
  final int approvalLevel;
  final String status;
  final String? comments;
  final String? approverName;

  NpdApprovalFlowItem({
    required this.id,
    required this.approvalLevel,
    required this.status,
    this.comments,
    this.approverName,
  });

  factory NpdApprovalFlowItem.fromJson(Map<String, dynamic> json) {
    final approver = json['approver'] as Map?;
    return NpdApprovalFlowItem(
      id: json['id'] as int? ?? 0,
      approvalLevel: json['approval_level'] as int? ?? 0,
      status: json['status']?.toString() ?? 'PENDING',
      comments: json['comments']?.toString(),
      approverName: approver?['nama_lengkap']?.toString(),
    );
  }
}

class NpdPendingApproval {
  final int id;
  final String number;
  final String? reportMonth;
  final String outletName;
  final String status;
  final int itemsCount;
  final String? creatorName;

  NpdPendingApproval({
    required this.id,
    required this.number,
    this.reportMonth,
    required this.outletName,
    required this.status,
    required this.itemsCount,
    this.creatorName,
  });

  factory NpdPendingApproval.fromJson(Map<String, dynamic> json) {
    return NpdPendingApproval(
      id: json['id'] as int? ?? 0,
      number: json['number']?.toString() ?? '',
      reportMonth: json['report_month']?.toString(),
      outletName: json['outlet_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      itemsCount: json['items_count'] as int? ?? 0,
      creatorName: json['creator_name']?.toString(),
    );
  }
}
