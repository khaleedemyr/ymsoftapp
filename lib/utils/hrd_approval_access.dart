/// HR-level approval access — izin/cuti HRD & koreksi attendance.
class HrdApprovalAccess {
  static const superadminRoleId = '5af56935b011a';
  static const hrApproverJabatanId = 309;

  static bool isSuperadmin(Map<String, dynamic>? user) {
    return user?['id_role']?.toString() == superadminRoleId;
  }

  static bool isHrApprover(Map<String, dynamic>? user) {
    final jabatanId = int.tryParse(user?['id_jabatan']?.toString() ?? '');
    return jabatanId == hrApproverJabatanId;
  }

  static bool canAccessHrdApprovals(Map<String, dynamic>? user) {
    if (user?['can_access_hrd_approvals'] == true) return true;
    return isSuperadmin(user) || isHrApprover(user);
  }
}
