/// Ticket status helpers — "resolved" is retired; legacy tickets map to closed.
String normalizeTicketStatusSlug(String? slug) {
  final s = slug?.trim().toLowerCase() ?? '';
  if (s == 'resolved') return 'closed';
  return s;
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
