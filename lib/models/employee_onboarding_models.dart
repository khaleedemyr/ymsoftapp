class EoPendingApproval {
  final int id;
  final int submissionId;
  final int weekNumber;
  final String number;
  final String? templateName;
  final String? employeeName;
  final String? outletName;

  EoPendingApproval({
    required this.id,
    required this.submissionId,
    required this.weekNumber,
    required this.number,
    this.templateName,
    this.employeeName,
    this.outletName,
  });

  factory EoPendingApproval.fromJson(Map<String, dynamic> json) {
    return EoPendingApproval(
      id: json['id'] as int? ?? 0,
      submissionId: json['submission_id'] as int? ?? 0,
      weekNumber: json['week_number'] as int? ?? 0,
      number: json['number']?.toString() ?? '',
      templateName: json['template_name']?.toString(),
      employeeName: json['employee_name']?.toString(),
      outletName: json['outlet_name']?.toString(),
    );
  }
}

class EoListItem {
  final int id;
  final String number;
  final String? templateName;
  final String? employeeName;
  final String status;
  final int currentWeek;
  final int unlockedWeek;
  final int totalWeeks;

  EoListItem({
    required this.id,
    required this.number,
    required this.templateName,
    required this.employeeName,
    required this.status,
    required this.currentWeek,
    required this.unlockedWeek,
    required this.totalWeeks,
  });

  factory EoListItem.fromJson(Map<String, dynamic> json) {
    return EoListItem(
      id: json['id'] as int? ?? 0,
      number: json['number']?.toString() ?? '',
      templateName: json['template_name']?.toString(),
      employeeName: json['employee_name']?.toString(),
      status: json['status']?.toString() ?? '',
      currentWeek: json['current_week'] as int? ?? 1,
      unlockedWeek: json['unlocked_week'] as int? ?? 1,
      totalWeeks: json['total_weeks'] as int? ?? 8,
    );
  }
}

class EoChecklistItem {
  final int id;
  final String areaName;
  final String checklistText;
  final String? assignedPicName;
  final int? assignedPicUserId;
  final String status;
  final String? remark;
  final bool canEdit;

  EoChecklistItem({
    required this.id,
    required this.areaName,
    required this.checklistText,
    this.assignedPicName,
    this.assignedPicUserId,
    required this.status,
    this.remark,
    this.canEdit = false,
  });

  factory EoChecklistItem.fromJson(Map<String, dynamic> json) {
    return EoChecklistItem(
      id: json['id'] as int? ?? 0,
      areaName: json['area_name']?.toString() ?? '',
      checklistText: json['checklist_text']?.toString() ?? '',
      assignedPicName: json['assigned_pic_name']?.toString(),
      assignedPicUserId: json['assigned_pic_user_id'] as int?,
      status: json['status']?.toString() ?? 'pending',
      remark: json['remark']?.toString(),
      canEdit: json['can_edit'] == true,
    );
  }
}
