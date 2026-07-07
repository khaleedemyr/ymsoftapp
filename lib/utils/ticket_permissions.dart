/// Selaras aturan ERP: superadmin, divisi 20, atau jabatan 343.
class TicketPermissions {
  static const String managerRoleId = '5af56935b011a';
  static const int managerDivisionId = 20;
  static const int managerJabatanId = 343;
  static const int vendorDivisionId = 18;

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

  static int? ticketDivisiId(Map<String, dynamic>? ticket) {
    if (ticket == null) return null;
    final raw = ticket['divisi_id'];
    if (raw is num) return raw.toInt();
    if (raw != null) return int.tryParse(raw.toString());
    if (ticket['divisi'] is Map) {
      final m = ticket['divisi'] as Map;
      final id = m['id'];
      if (id is num) return id.toInt();
      return int.tryParse(id?.toString() ?? '');
    }
    return null;
  }

  static bool ticketIsExternalVendor(Map<String, dynamic>? ticket) {
    return ticket?['work_executor_type']?.toString() == 'external_vendor';
  }

  static bool userIsVendorDivision(Map<String, dynamic>? user) {
    final div = int.tryParse(user?['division_id']?.toString() ?? '') ?? 0;
    return div == vendorDivisionId;
  }

  static bool userCanManageVendorExternalTicket(
    Map<String, dynamic>? ticket,
    Map<String, dynamic>? user,
  ) {
    return ticketIsExternalVendor(ticket) && userIsVendorDivision(user);
  }

  static bool ticketCanManage(Map<String, dynamic>? ticket, Map<String, dynamic>? user) {
    if (ticket != null && ticket.containsKey('can_manage_ticket')) {
      final v = ticket['can_manage_ticket'];
      if (v == true || v == 1) return true;
    }
    if (userCanManage(user)) return true;
    return userCanManageVendorExternalTicket(ticket, user);
  }

  /// Ubah status: admin global ATAU divisi user = divisi concern ATAU divisi 18 pada external vendor.
  static bool ticketCanUpdateStatus(
    Map<String, dynamic>? ticket,
    Map<String, dynamic>? user,
  ) {
    if (ticket == null) return false;
    if (ticket.containsKey('can_update_status')) {
      final v = ticket['can_update_status'];
      return v == true || v == 1;
    }
    if (userCanManage(user)) return true;
    if (userCanManageVendorExternalTicket(ticket, user)) return true;
    final userDiv = int.tryParse(user?['division_id']?.toString() ?? '') ?? 0;
    final ticketDiv = ticketDivisiId(ticket);
    return userDiv > 0 && ticketDiv != null && userDiv == ticketDiv;
  }

  static bool ticketCanUpdateVendorName(
    Map<String, dynamic>? ticket,
    Map<String, dynamic>? user,
  ) {
    if (!ticketIsExternalVendor(ticket)) return false;
    if (ticket!.containsKey('can_update_vendor_name')) {
      final v = ticket['can_update_vendor_name'];
      return v == true || v == 1;
    }
    if (userCanManage(user)) return true;
    if (userCanManageVendorExternalTicket(ticket, user)) return true;
    return ticketCanSetWorkExecutorType(ticket, user);
  }

  /// Isi dikerjakan oleh (internal / external vendor): hanya divisi concern ticket.
  static bool ticketCanSetWorkExecutorType(
    Map<String, dynamic>? ticket,
    Map<String, dynamic>? user,
  ) {
    if (ticket == null) return false;
    if (ticket.containsKey('can_set_work_executor_type')) {
      final v = ticket['can_set_work_executor_type'];
      return v == true || v == 1;
    }
    final userDiv = int.tryParse(user?['division_id']?.toString() ?? '') ?? 0;
    final ticketDiv = ticketDivisiId(ticket);
    return userDiv > 0 && ticketDiv != null && userDiv == ticketDiv;
  }

  static String? workExecutorTypeLabel(String? type) {
    switch (type) {
      case 'internal':
        return 'Internal';
      case 'external_vendor':
        return 'External Vendor';
      default:
        return null;
    }
  }
}
