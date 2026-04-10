/// Selaras aturan ERP: superadmin, divisi 20, atau jabatan 343.
class TicketPermissions {
  static const String managerRoleId = '5af56935b011a';
  static const int managerDivisionId = 20;
  static const int managerJabatanId = 343;

  static bool userCanManage(Map<String, dynamic>? u) {
    if (u == null) return false;
    final role = u['id_role']?.toString() ?? '';
    if (role == managerRoleId) return true;
    final div = int.tryParse(u['division_id']?.toString() ?? '') ?? 0;
    if (div == managerDivisionId) return true;
    final jab = int.tryParse(u['id_jabatan']?.toString() ?? '') ?? 0;
    if (jab == managerJabatanId) return true;
    return false;
  }
}
