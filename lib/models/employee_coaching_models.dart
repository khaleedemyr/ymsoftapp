class EmployeeCoachingListItem {
  final int id;
  final int employeeId;
  final String employeeName;
  final String outletName;
  final String jabatanName;
  final String? reviewPlanDate;
  final String? createdAt;
  final String? createdByName;

  EmployeeCoachingListItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.outletName,
    required this.jabatanName,
    this.reviewPlanDate,
    this.createdAt,
    this.createdByName,
  });

  factory EmployeeCoachingListItem.fromJson(Map<String, dynamic> json) {
    return EmployeeCoachingListItem(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int? ?? 0,
      employeeName: json['employee_name']?.toString() ?? '-',
      outletName: json['outlet_name']?.toString() ?? '-',
      jabatanName: json['jabatan_name']?.toString() ?? '-',
      reviewPlanDate: json['performance_review_plan_date']?.toString(),
      createdAt: json['created_at']?.toString(),
      createdByName: json['created_by_name']?.toString(),
    );
  }
}

class ConcernOption {
  final String code;
  final String labelEn;
  final String labelId;

  ConcernOption({
    required this.code,
    required this.labelEn,
    required this.labelId,
  });

  factory ConcernOption.fromJson(Map<String, dynamic> json) {
    return ConcernOption(
      code: json['code']?.toString() ?? '',
      labelEn: json['label_en']?.toString() ?? '',
      labelId: json['label_id']?.toString() ?? '',
    );
  }
}

class EmployeeSuggestion {
  final int id;
  final String namaLengkap;
  final String jabatanName;
  final String outletName;
  final String divisionName;

  EmployeeSuggestion({
    required this.id,
    required this.namaLengkap,
    required this.jabatanName,
    required this.outletName,
    required this.divisionName,
  });

  factory EmployeeSuggestion.fromJson(Map<String, dynamic> json) {
    return EmployeeSuggestion(
      id: json['id'] as int,
      namaLengkap: json['nama_lengkap']?.toString() ?? '',
      jabatanName: json['jabatan_name']?.toString() ?? '-',
      outletName: json['outlet_name']?.toString() ?? '-',
      divisionName: json['division_name']?.toString() ?? '-',
    );
  }
}

class ConcernState {
  bool checked;
  String comment;
  String otherLabel;

  ConcernState({
    this.checked = false,
    this.comment = '',
    this.otherLabel = '',
  });

  Map<String, dynamic> toPayload(String code) {
    return {
      'code': code,
      'comment': comment.trim(),
      'other_label': code == 'other' ? (otherLabel.trim().isEmpty ? null : otherLabel.trim()) : null,
    };
  }
}

class EmployeeCoachingConcernRow {
  final int? id;
  final String concernCode;
  final String? otherLabel;
  final String comment;

  EmployeeCoachingConcernRow({
    this.id,
    required this.concernCode,
    this.otherLabel,
    required this.comment,
  });

  factory EmployeeCoachingConcernRow.fromJson(Map<String, dynamic> json) {
    return EmployeeCoachingConcernRow(
      id: json['id'] as int?,
      concernCode: json['concern_code']?.toString() ?? '',
      otherLabel: json['other_label']?.toString(),
      comment: json['comment']?.toString() ?? '',
    );
  }
}
