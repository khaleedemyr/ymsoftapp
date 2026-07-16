class SopUserOption {
  final int id;
  final String name;
  final String? jabatan;
  final String? email;

  SopUserOption({
    required this.id,
    required this.name,
    this.jabatan,
    this.email,
  });

  factory SopUserOption.fromJson(Map<String, dynamic> json) {
    return SopUserOption(
      id: json['id'] as int? ?? int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['nama_lengkap']?.toString() ?? '',
      jabatan: json['jabatan']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class SopApprovalFlowItem {
  final int id;
  final int approvalLevel;
  final String status;
  final String? approverName;

  SopApprovalFlowItem({
    required this.id,
    required this.approvalLevel,
    required this.status,
    this.approverName,
  });

  factory SopApprovalFlowItem.fromJson(Map<String, dynamic> json) {
    final approver = json['approver'] as Map?;
    return SopApprovalFlowItem(
      id: json['id'] as int? ?? 0,
      approvalLevel: json['approval_level'] as int? ?? 0,
      status: json['status']?.toString() ?? '',
      approverName: approver?['nama_lengkap']?.toString(),
    );
  }
}

class SopListItem {
  final int id;
  final String title;
  final String? description;
  final String? dueDate;
  final String status;
  final String statusText;
  final String? fileOriginalName;
  final bool hasFile;
  final bool isOverdue;
  final String? creatorName;
  final int? userId;
  final List<SopApprovalFlowItem> approvalFlows;
  final bool canDelete;
  final bool canSubmit;

  SopListItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.status,
    required this.statusText,
    this.fileOriginalName,
    required this.hasFile,
    required this.isOverdue,
    this.creatorName,
    this.userId,
    required this.approvalFlows,
    required this.canDelete,
    required this.canSubmit,
  });

  factory SopListItem.fromJson(Map<String, dynamic> json) {
    return SopListItem(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      dueDate: json['due_date']?.toString(),
      status: json['status']?.toString() ?? '',
      statusText: json['status_text']?.toString() ?? json['status']?.toString() ?? '',
      fileOriginalName: json['file_original_name']?.toString(),
      hasFile: json['file_path'] != null && json['file_path'].toString().isNotEmpty,
      isOverdue: json['is_overdue'] == true,
      creatorName: json['creator_name']?.toString(),
      userId: json['user_id'] as int?,
      approvalFlows: (json['approval_flows'] as List? ?? [])
          .map((e) => SopApprovalFlowItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      canDelete: json['can_delete'] == true,
      canSubmit: json['can_submit'] == true,
    );
  }
}

class SopPendingApproval {
  final int id;
  final String title;
  final String? description;
  final String? dueDate;
  final String? creatorName;
  final int? approvalLevel;
  final String? approverName;

  SopPendingApproval({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.creatorName,
    this.approvalLevel,
    this.approverName,
  });

  factory SopPendingApproval.fromJson(Map<String, dynamic> json) {
    return SopPendingApproval(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      dueDate: json['due_date']?.toString(),
      creatorName: json['creator_name']?.toString() ?? json['user']?['nama_lengkap']?.toString(),
      approvalLevel: json['approval_level'] as int?,
      approverName: json['approver_name']?.toString(),
    );
  }
}
