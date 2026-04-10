// Approval Models

// Helper function to safely parse double from JSON (handles both string and number)
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

class PurchaseRequisitionApproval {
  final int id;
  final String prNumber;
  final String? title;
  final String? divisionName;
  final String? outletName;
  final double? amount;
  final String? status;
  final String? mode; // pr_ops, purchase_payment, travel_application, kasbon
  final String? approverName;
  final int? unreadCommentsCount;
  final Map<String, dynamic>? division;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  PurchaseRequisitionApproval({
    required this.id,
    required this.prNumber,
    this.title,
    this.divisionName,
    this.outletName,
    this.amount,
    this.status,
    this.mode,
    this.approverName,
    this.unreadCommentsCount,
    this.division,
    this.outlet,
    this.creator,
    this.createdAt,
  });

  factory PurchaseRequisitionApproval.fromJson(Map<String, dynamic> json) {
    return PurchaseRequisitionApproval(
      id: json['id'] ?? 0,
      prNumber: json['pr_number'] ?? '',
      title: json['title'],
      divisionName: json['division']?['nama_divisi'],
      outletName: json['outlet']?['nama_outlet'],
      amount: _parseDouble(json['amount']),
      status: json['status'],
      mode: json['mode'],
      approverName: json['approver_name'],
      unreadCommentsCount: json['unread_comments_count'],
      division: json['division'],
      outlet: json['outlet'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class PurchaseOrderOpsApproval {
  final int id;
  final String number;
  final String? supplierName;
  final String? prNumber;
  final String? prTitle;
  final String? outletName;
  final String? divisionName;
  final double? grandTotal;
  final String? approverName;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? purchaseRequisition;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  PurchaseOrderOpsApproval({
    required this.id,
    required this.number,
    this.supplierName,
    this.prNumber,
    this.prTitle,
    this.outletName,
    this.divisionName,
    this.grandTotal,
    this.approverName,
    this.supplier,
    this.purchaseRequisition,
    this.creator,
    this.createdAt,
  });

  factory PurchaseOrderOpsApproval.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderOpsApproval(
      id: json['id'] ?? 0,
      number: json['number'] ?? '',
      supplierName: json['supplier']?['name'],
      prNumber: json['purchase_requisition']?['pr_number'],
      prTitle: json['purchase_requisition']?['title'],
      outletName: json['purchase_requisition']?['outlet']?['nama_outlet'],
      divisionName: json['purchase_requisition']?['division']?['nama_divisi'],
      grandTotal: _parseDouble(json['grand_total']),
      approverName: json['approver_name'],
      supplier: json['supplier'],
      purchaseRequisition: json['purchase_requisition'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class LeaveApproval {
  final int id;
  final String employeeName;
  final String leaveTypeName;
  final String durationText;
  final DateTime dateFrom;
  final DateTime dateTo;
  final bool isHrdApproval;
  final String? approverName;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? leaveType;
  final DateTime? createdAt;

  LeaveApproval({
    required this.id,
    required this.employeeName,
    required this.leaveTypeName,
    required this.durationText,
    required this.dateFrom,
    required this.dateTo,
    this.isHrdApproval = false,
    this.approverName,
    this.user,
    this.leaveType,
    this.createdAt,
  });

  factory LeaveApproval.fromJson(Map<String, dynamic> json) {
    return LeaveApproval(
      id: json['id'] ?? 0,
      employeeName: json['user']?['nama_lengkap'] ?? '',
      leaveTypeName: json['leave_type']?['name'] ?? '',
      durationText: json['duration_text'] ?? '',
      dateFrom: DateTime.parse(json['date_from']),
      dateTo: DateTime.parse(json['date_to']),
      isHrdApproval: json['is_hrd_approval'] ?? false,
      approverName: json['approver_name'],
      user: json['user'],
      leaveType: json['leave_type'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class CategoryCostApproval {
  final int id;
  final String? outletName;
  final String? approverName;
  final String? categoryName;
  final double? amount;
  final String? status;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? category;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  CategoryCostApproval({
    required this.id,
    this.outletName,
    this.approverName,
    this.categoryName,
    this.amount,
    this.status,
    this.outlet,
    this.category,
    this.creator,
    this.createdAt,
  });

  factory CategoryCostApproval.fromJson(Map<String, dynamic> json) {
    return CategoryCostApproval(
      id: json['id'] ?? 0,
      outletName: json['outlet_name'] ?? json['outlet']?['nama_outlet'],
      approverName: json['approver_name'],
      categoryName: json['category']?['name'],
      amount: _parseDouble(json['amount']),
      status: json['status'],
      outlet: json['outlet'],
      category: json['category'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class StockAdjustmentApproval {
  final int id;
  final String? outletName;
  final String? approverName;
  final String? adjustmentType;
  final String? status;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  StockAdjustmentApproval({
    required this.id,
    this.outletName,
    this.approverName,
    this.adjustmentType,
    this.status,
    this.outlet,
    this.creator,
    this.createdAt,
  });

  factory StockAdjustmentApproval.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentApproval(
      id: json['id'] ?? 0,
      outletName: json['outlet_name'] ?? json['outlet']?['nama_outlet'],
      approverName: json['approver_name'],
      adjustmentType: json['type'] ?? json['adjustment_type'],
      status: json['status'],
      outlet: json['outlet'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

/// Warehouse Stock Adjustment (Food Inventory Adjustment) - list item for pending approvals
class WarehouseStockAdjustmentApproval {
  final int id;
  final String number;
  final String? date;
  final String? type;
  final String? reason;
  final String? status;
  final String? warehouseName;
  final String? creatorName;
  final int? itemsCount;
  final String? approverName;
  final Map<String, dynamic>? warehouse;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  WarehouseStockAdjustmentApproval({
    required this.id,
    required this.number,
    this.date,
    this.type,
    this.reason,
    this.status,
    this.warehouseName,
    this.creatorName,
    this.itemsCount,
    this.approverName,
    this.warehouse,
    this.creator,
    this.createdAt,
  });

  factory WarehouseStockAdjustmentApproval.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'];
    final creator = json['creator'];
    return WarehouseStockAdjustmentApproval(
      id: int.tryParse(json['id'].toString()) ?? 0,
      number: json['number']?.toString() ?? '-',
      date: json['date']?.toString(),
      type: json['type']?.toString(),
      reason: json['reason']?.toString(),
      status: json['status']?.toString(),
      warehouseName: warehouse is Map ? warehouse['name']?.toString() : null,
      creatorName: creator is Map ? (creator['nama_lengkap'] ?? creator['name'])?.toString() : null,
      itemsCount: json['items_count'] != null ? int.tryParse(json['items_count'].toString()) : null,
      approverName: json['approver_name']?.toString(),
      warehouse: warehouse is Map ? Map<String, dynamic>.from(warehouse) : null,
      creator: creator is Map ? Map<String, dynamic>.from(creator) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class StockOpnameApproval {
  final int id;
  final String opnameNumber;
  final String? outletName;
  final String? warehouseOutletName;
  final String? opnameDate;
  final String? creatorName;
  final String? approverName;
  final int? approvalLevel;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? warehouseOutlet;
  final Map<String, dynamic>? creator;

  StockOpnameApproval({
    required this.id,
    required this.opnameNumber,
    this.outletName,
    this.warehouseOutletName,
    this.opnameDate,
    this.creatorName,
    this.approverName,
    this.approvalLevel,
    this.outlet,
    this.warehouseOutlet,
    this.creator,
  });

  factory StockOpnameApproval.fromJson(Map<String, dynamic> json) {
    return StockOpnameApproval(
      id: json['id'] ?? 0,
      opnameNumber: json['opname_number'] ?? '',
      outletName: json['outlet']?['nama_outlet'],
      warehouseOutletName: json['warehouse_outlet']?['name'],
      opnameDate: json['opname_date']?.toString(),
      creatorName: json['creator']?['nama_lengkap'],
      approverName: json['approver_name']?.toString(),
      approvalLevel: json['approval_level'],
      outlet: json['outlet'],
      warehouseOutlet: json['warehouse_outlet'],
      creator: json['creator'],
    );
  }
}

/// Pending approval card for warehouse (gudang) stock opname — API key `warehouse_stock_opnames`.
class WarehouseStockOpnameApproval {
  final int id;
  final String opnameNumber;
  final String? warehouseName;
  final String? divisionName;
  final String? opnameDate;
  final String? creatorName;
  final String? approverName;
  final int? approvalLevel;
  final Map<String, dynamic>? warehouse;
  final Map<String, dynamic>? warehouseDivision;
  final Map<String, dynamic>? creator;

  WarehouseStockOpnameApproval({
    required this.id,
    required this.opnameNumber,
    this.warehouseName,
    this.divisionName,
    this.opnameDate,
    this.creatorName,
    this.approverName,
    this.approvalLevel,
    this.warehouse,
    this.warehouseDivision,
    this.creator,
  });

  factory WarehouseStockOpnameApproval.fromJson(Map<String, dynamic> json) {
    return WarehouseStockOpnameApproval(
      id: json['id'] ?? 0,
      opnameNumber: json['opname_number']?.toString() ?? '',
      warehouseName: json['warehouse'] is Map
          ? (json['warehouse'] as Map)['name']?.toString()
          : null,
      divisionName: json['warehouse_division'] is Map
          ? (json['warehouse_division'] as Map)['name']?.toString()
          : null,
      opnameDate: json['opname_date']?.toString(),
      creatorName: json['creator'] is Map
          ? (json['creator'] as Map)['nama_lengkap']?.toString()
          : null,
      approverName: json['approver_name']?.toString(),
      approvalLevel: json['approval_level'] is int
          ? json['approval_level'] as int
          : int.tryParse(json['approval_level']?.toString() ?? ''),
      warehouse: json['warehouse'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['warehouse'] as Map)
          : null,
      warehouseDivision: json['warehouse_division'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['warehouse_division'] as Map)
          : null,
      creator: json['creator'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['creator'] as Map)
          : null,
    );
  }
}

/// Pending CCTV access request (IT Manager) — list from `data` array on pending API.
class CctvAccessRequestApproval {
  final int id;
  final String accessType;
  final String? requesterName;
  final String? reason;
  final List<dynamic>? outletIds;
  final String? email;
  final String? area;
  final DateTime? createdAt;
  final Map<String, dynamic>? user;

  CctvAccessRequestApproval({
    required this.id,
    required this.accessType,
    this.requesterName,
    this.reason,
    this.outletIds,
    this.email,
    this.area,
    this.createdAt,
    this.user,
  });

  String get accessTypeLabel {
    switch (accessType) {
      case 'live_view':
        return 'Live View';
      case 'playback':
        return 'Playback';
      default:
        return accessType;
    }
  }

  int get outletCount => outletIds?.length ?? 0;

  factory CctvAccessRequestApproval.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? userMap;
    final u = json['user'];
    if (u is Map) {
      userMap = Map<String, dynamic>.from(u);
    }
    List<dynamic>? oids;
    final raw = json['outlet_ids'];
    if (raw is List) oids = raw;

    DateTime? created;
    final ca = json['created_at'];
    if (ca != null) {
      created = DateTime.tryParse(ca.toString());
    }

    final idVal = json['id'];
    final id = idVal is int ? idVal : int.tryParse(idVal?.toString() ?? '0') ?? 0;

    return CctvAccessRequestApproval(
      id: id,
      accessType: json['access_type']?.toString() ?? '',
      requesterName: userMap?['nama_lengkap']?.toString(),
      reason: json['reason']?.toString(),
      outletIds: oids,
      email: json['email']?.toString(),
      area: json['area']?.toString(),
      createdAt: created,
      user: userMap,
    );
  }
}

class OutletTransferApproval {
  final int id;
  final String transferNumber;
  final String? transferDate;
  final String? notes;
  final String? outletName;
  final String? warehouseFromName;
  final String? warehouseToName;
  final String? creatorName;
  final String? approverName;
  final int? approvalLevel;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? warehouseOutletFrom;
  final Map<String, dynamic>? warehouseOutletTo;
  final Map<String, dynamic>? creator;

  OutletTransferApproval({
    required this.id,
    required this.transferNumber,
    this.transferDate,
    this.notes,
    this.outletName,
    this.warehouseFromName,
    this.warehouseToName,
    this.creatorName,
    this.approverName,
    this.approvalLevel,
    this.outlet,
    this.warehouseOutletFrom,
    this.warehouseOutletTo,
    this.creator,
  });

  factory OutletTransferApproval.fromJson(Map<String, dynamic> json) {
    return OutletTransferApproval(
      id: json['id'] ?? 0,
      transferNumber: json['transfer_number'] ?? '',
      transferDate: json['transfer_date']?.toString(),
      notes: json['notes']?.toString(),
      outletName: json['outlet']?['nama_outlet'],
      warehouseFromName: json['warehouse_outlet_from']?['name'],
      warehouseToName: json['warehouse_outlet_to']?['name'],
      creatorName: json['creator']?['nama_lengkap'],
      approverName: json['approver_name']?.toString(),
      approvalLevel: json['approval_level'],
      outlet: json['outlet'],
      warehouseOutletFrom: json['warehouse_outlet_from'],
      warehouseOutletTo: json['warehouse_outlet_to'],
      creator: json['creator'],
    );
  }
}

class ContraBonApproval {
  final int id;
  final String number;
  final String? supplierName;
  final double? totalAmount;
  final String? status;
  final String? sourceType;
  final String? approvalLevel;
  final String? approverName;
  final DateTime? date;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  ContraBonApproval({
    required this.id,
    required this.number,
    this.supplierName,
    this.totalAmount,
    this.status,
    this.sourceType,
    this.approvalLevel,
    this.approverName,
    this.date,
    this.supplier,
    this.creator,
    this.createdAt,
  });

  factory ContraBonApproval.fromJson(Map<String, dynamic> json) {
    return ContraBonApproval(
      id: json['id'] ?? 0,
      number: json['number'] ?? '',
      supplierName: json['supplier']?['name'],
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'],
      sourceType: json['source_type'],
      approvalLevel: json['approval_level']?.toString(),
      approverName: json['approver_name'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      supplier: json['supplier'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class EmployeeMovementApproval {
  final int id;
  final String employeeName;
  final String? employmentType;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? employee;
  final List<Map<String, dynamic>>? approvalFlows;
  final DateTime? createdAt;

  EmployeeMovementApproval({
    required this.id,
    required this.employeeName,
    this.employmentType,
    this.status,
    this.approverName,
    this.employee,
    this.approvalFlows,
    this.createdAt,
  });

  factory EmployeeMovementApproval.fromJson(Map<String, dynamic> json) {
    return EmployeeMovementApproval(
      id: json['id'] ?? 0,
      employeeName: json['employee_name'] ?? '',
      employmentType: json['employment_type'],
      status: json['status'],
      approverName: json['approver_name'],
      employee: json['employee'],
      approvalFlows: json['approval_flows'] != null
          ? List<Map<String, dynamic>>.from(json['approval_flows'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class CoachingApproval {
  final int id;
  final String employeeName;
  final String supervisorName;
  final DateTime violationDate;
  final String violationDetails;
  final int? approvalLevel;
  final String? approverName;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? supervisor;
  final DateTime? createdAt;

  CoachingApproval({
    required this.id,
    required this.employeeName,
    required this.supervisorName,
    required this.violationDate,
    required this.violationDetails,
    this.approvalLevel,
    this.approverName,
    this.employee,
    this.supervisor,
    this.createdAt,
  });

  factory CoachingApproval.fromJson(Map<String, dynamic> json) {
    return CoachingApproval(
      id: json['id'] ?? 0,
      employeeName: json['employee_name'] ?? '',
      supervisorName: json['supervisor_name'] ?? '',
      violationDate: DateTime.parse(json['violation_date']),
      violationDetails: json['violation_details'] ?? '',
      approvalLevel: json['approval_level'],
      approverName: json['approver_name'],
      employee: json['employee'],
      supervisor: json['supervisor'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class CorrectionApproval {
  final int id;
  final String employeeName;
  final String outletName;
  final String type; // schedule, attendance, manual
  final DateTime tanggal;
  final String? reason;
  final String? approverName;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? outlet;
  final DateTime? createdAt;

  CorrectionApproval({
    required this.id,
    required this.employeeName,
    required this.outletName,
    required this.type,
    required this.tanggal,
    this.reason,
    this.approverName,
    this.employee,
    this.outlet,
    this.createdAt,
  });

  factory CorrectionApproval.fromJson(Map<String, dynamic> json) {
    return CorrectionApproval(
      id: json['id'] ?? 0,
      employeeName: json['employee_name'] ?? '',
      outletName: json['nama_outlet'] ?? '',
      type: json['type'] ?? '',
      tanggal: DateTime.parse(json['tanggal']),
      reason: json['reason'],
      approverName: json['approver_name'],
      employee: json['employee'],
      outlet: json['outlet'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class FoodPaymentApproval {
  final int id;
  final String? number;
  final String? supplierName;
  final double? totalAmount;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  FoodPaymentApproval({
    required this.id,
    this.number,
    this.supplierName,
    this.totalAmount,
    this.status,
    this.approverName,
    this.supplier,
    this.creator,
    this.createdAt,
  });

  factory FoodPaymentApproval.fromJson(Map<String, dynamic> json) {
    return FoodPaymentApproval(
      id: json['id'] ?? 0,
      number: json['number'],
      supplierName: json['supplier']?['name'],
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'],
      approverName: json['approver_name'],
      supplier: json['supplier'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class NonFoodPaymentApproval {
  final int id;
  final String? number;
  final String? supplierName;
  final double? totalAmount;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  NonFoodPaymentApproval({
    required this.id,
    this.number,
    this.supplierName,
    this.totalAmount,
    this.status,
    this.approverName,
    this.supplier,
    this.creator,
    this.createdAt,
  });

  factory NonFoodPaymentApproval.fromJson(Map<String, dynamic> json) {
    return NonFoodPaymentApproval(
      id: json['id'] ?? 0,
      number: json['number'],
      supplierName: json['supplier']?['name'],
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'],
      approverName: json['approver_name'],
      supplier: json['supplier'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class PRFoodApproval {
  final int id;
  final String? prNumber;
  final String? title;
  final double? amount;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? creator;
  final Map<String, dynamic>? requester;
  final Map<String, dynamic>? warehouse;
  final String? creatorName; // For direct nama_lengkap from root level
  final DateTime? createdAt;

  PRFoodApproval({
    required this.id,
    this.prNumber,
    this.title,
    this.amount,
    this.status,
    this.approverName,
    this.creator,
    this.requester,
    this.warehouse,
    this.creatorName,
    this.createdAt,
  });

  factory PRFoodApproval.fromJson(Map<String, dynamic> json) {
    return PRFoodApproval(
      id: json['id'] ?? 0,
      prNumber: json['pr_number'],
      title: json['title'],
      amount: _parseDouble(json['amount']),
      status: json['status'],
      approverName: json['approver_name'],
      creator: json['creator'],
      requester: json['requester'],
      warehouse: json['warehouse'],
      creatorName: json['requester']?['nama_lengkap'] ?? json['nama_lengkap'] ?? json['creator']?['nama_lengkap'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class POFoodApproval {
  final int id;
  final String? number;
  final String? supplierName;
  final double? totalAmount;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? supplier;
  final Map<String, dynamic>? creator;
  final DateTime? createdAt;

  POFoodApproval({
    required this.id,
    this.number,
    this.supplierName,
    this.totalAmount,
    this.status,
    this.approverName,
    this.supplier,
    this.creator,
    this.createdAt,
  });

  factory POFoodApproval.fromJson(Map<String, dynamic> json) {
    return POFoodApproval(
      id: json['id'] ?? 0,
      number: json['number'],
      supplierName: json['supplier']?['name'],
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'],
      approverName: json['approver_name'],
      supplier: json['supplier'],
      creator: json['creator'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class ROKhususApproval {
  final int id;
  final String? number;
  final String? outletName;
  final double? totalAmount;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? outlet;
  final Map<String, dynamic>? warehouseOutlet;
  final Map<String, dynamic>? creator;
  final Map<String, dynamic>? requester;
  final DateTime? createdAt;

  ROKhususApproval({
    required this.id,
    this.number,
    this.outletName,
    this.totalAmount,
    this.status,
    this.approverName,
    this.outlet,
    this.warehouseOutlet,
    this.creator,
    this.requester,
    this.createdAt,
  });

  factory ROKhususApproval.fromJson(Map<String, dynamic> json) {
    return ROKhususApproval(
      id: json['id'] ?? 0,
      number: json['order_number'] ?? json['number'],
      outletName: json['outlet']?['nama_outlet'],
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'],
      approverName: json['approver_name'],
      outlet: json['outlet'],
      warehouseOutlet: json['warehouse_outlet'],
      creator: json['creator'],
      requester: json['requester'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class EmployeeResignationApproval {
  final int id;
  final String employeeName;
  final DateTime? resignationDate;
  final String? reason;
  final String? status;
  final String? approverName;
  final Map<String, dynamic>? employee;
  final List<Map<String, dynamic>>? approvalFlows;
  final DateTime? createdAt;

  EmployeeResignationApproval({
    required this.id,
    required this.employeeName,
    this.resignationDate,
    this.reason,
    this.status,
    this.approverName,
    this.employee,
    this.approvalFlows,
    this.createdAt,
  });

  factory EmployeeResignationApproval.fromJson(Map<String, dynamic> json) {
    return EmployeeResignationApproval(
      id: json['id'] ?? 0,
      employeeName: json['employee']?['nama_lengkap'] ?? '',
      resignationDate: json['resignation_date'] != null
          ? DateTime.parse(json['resignation_date'])
          : null,
      reason: json['reason'],
      status: json['status'],
      approverName: json['approver_name'],
      employee: json['employee'],
      approvalFlows: json['approval_flows'] != null
          ? List<Map<String, dynamic>>.from(json['approval_flows'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

