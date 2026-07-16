/// Selaras dengan `FoodFloorOrder::canEdit()` / `editCutoffAt()` di backend.
class FloorOrderEditPolicy {
  static const int editCutoffHour = 7;

  static const String lockedMessage =
      'Request Order tidak dapat diedit karena sudah melewati batas waktu edit (besok jam 07:00).';

  static bool canEditFromApi(Map<String, dynamic> order) {
    final foMode = order['fo_mode']?.toString();
    final status = order['status']?.toString().toLowerCase() ?? '';

    if (foMode == 'RO Supplier' && status != 'draft') {
      return false;
    }

    if (!['draft', 'approved', 'submitted'].contains(status)) {
      return false;
    }

    final canEdit = order['can_edit'];
    if (canEdit is bool) return canEdit;
    if (canEdit == 1 || canEdit == '1') return true;
    if (canEdit == 0 || canEdit == '0') return false;

    return isWithinEditWindow(order);
  }

  /// Tanggal dibuat + 1 hari jam 07:00 (besok pagi).
  static DateTime? editCutoffAt(Map<String, dynamic> order) {
    final createdRaw = order['created_at']?.toString();
    if (createdRaw == null || createdRaw.isEmpty) {
      return null;
    }

    DateTime created;
    try {
      created = DateTime.parse(createdRaw).toLocal();
    } catch (_) {
      return null;
    }

    return DateTime(
      created.year,
      created.month,
      created.day,
      editCutoffHour,
    ).add(const Duration(days: 1));
  }

  static bool isWithinEditWindow(Map<String, dynamic> order) {
    final cutoff = editCutoffAt(order);
    if (cutoff == null) return false;
    return DateTime.now().isBefore(cutoff);
  }
}
