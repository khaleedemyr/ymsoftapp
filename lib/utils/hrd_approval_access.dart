/// HR-level approval access — izin/cuti HRD & koreksi attendance.
class HrdApprovalAccess {
  static const superadminRoleId = '5af56935b011a';

  /// 309 = HR Generalist, 153 = GM HR
  static const hrApproverJabatanIds = [309, 153];

  static bool isSuperadmin(Map<String, dynamic>? user) {
    return user?['id_role']?.toString() == superadminRoleId;
  }

  static bool isHrApprover(Map<String, dynamic>? user) {
    final jabatanId = int.tryParse(user?['id_jabatan']?.toString() ?? '');
    return jabatanId != null && hrApproverJabatanIds.contains(jabatanId);
  }

  static bool canAccessHrdApprovals(Map<String, dynamic>? user) {
    if (user?['can_access_hrd_approvals'] == true) return true;
    return isSuperadmin(user) || isHrApprover(user);
  }
}
