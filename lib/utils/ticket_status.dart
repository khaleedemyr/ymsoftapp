/// Ticket status helpers — "resolved" is retired; legacy tickets map to closed.
String normalizeTicketStatusSlug(String? slug) {
  final s = slug?.trim().toLowerCase() ?? '';
  if (s == 'resolved') return 'closed';
  return s;
}

/// Status ticket yang ditampilkan saat cek duplikasi (create / daily report).
const Set<String> activeTicketStatusSlugsForDedup = {
  'open',
  'in_progress',
  'pending',
};

bool isActiveTicketForDedup(dynamic ticket) {
  if (ticket is! Map) return false;
  final status = ticket['status'];
  if (status is! Map) return false;
  final slug = status['slug']?.toString().trim().toLowerCase() ?? '';
  return activeTicketStatusSlugsForDedup.contains(slug);
}

List<Map<String, dynamic>> filterActiveTicketsForDedup(List<dynamic> tickets) {
  return tickets
      .whereType<Map>()
      .cast<Map<String, dynamic>>()
      .where(isActiveTicketForDedup)
      .toList();
}

int duplicateActiveTicketCount(List<Map<String, dynamic>> tickets) {
  return tickets.where((t) => t['is_same_title'] == true).length;
}

String displayTicketStatusName(String? name, String? slug) {
  if (normalizeTicketStatusSlug(slug) == 'closed' && (slug?.toLowerCase() == 'resolved')) {
    return 'Closed';
  }
  return name?.trim().isNotEmpty == true ? name!.trim() : '-';
}

bool isSelectableTicketStatus(dynamic status) {
  if (status is! Map) return true;
  return normalizeTicketStatusSlug(status['slug']?.toString()) != 'resolved';
}

List<dynamic> selectableTicketStatuses(List<dynamic> statuses) {
  return statuses.where((s) => isSelectableTicketStatus(s)).toList();
}
