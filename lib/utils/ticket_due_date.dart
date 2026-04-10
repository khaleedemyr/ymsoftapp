import 'package:flutter/material.dart';

/// Selaras dengan `getDueDateStatus` / `getDueDateBadgeClass` di `Tickets/Index.vue`.
class TicketDueDateStyle {
  final String badgeLabel;
  final Color backgroundColor;
  final Color foregroundColor;

  const TicketDueDateStyle({
    required this.badgeLabel,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  static TicketDueDateStyle compute({
    required String? dueIso,
    String? statusSlug,
  }) {
    const grayBg = Color(0xFFF3F4F6);
    const grayFg = Color(0xFF6B7280);

    if (dueIso == null || dueIso.isEmpty) {
      return const TicketDueDateStyle(
        badgeLabel: 'No Due Date',
        backgroundColor: grayBg,
        foregroundColor: grayFg,
      );
    }

    DateTime? due;
    try {
      due = DateTime.parse(dueIso);
    } catch (_) {
      return const TicketDueDateStyle(
        badgeLabel: '-',
        backgroundColor: grayBg,
        foregroundColor: grayFg,
      );
    }

    final now = DateTime.now();
    final diffMs = due.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    final diffDays = (diffMs / Duration.millisecondsPerDay).ceil();

    final String statusText;
    if (diffDays < 0) {
      statusText = 'Overdue';
    } else if (diffDays == 0) {
      statusText = 'Due Today';
    } else if (diffDays == 1) {
      statusText = 'Due Tomorrow';
    } else {
      statusText = '$diffDays days left';
    }

    if (diffDays < 0) {
      return TicketDueDateStyle(
        badgeLabel: statusText,
        backgroundColor: const Color(0xFFFEE2E2),
        foregroundColor: const Color(0xFFDC2626),
      );
    }
    if (statusSlug == 'closed' || statusSlug == 'resolved') {
      return TicketDueDateStyle(
        badgeLabel: statusText,
        backgroundColor: const Color(0xFFDCFCE7),
        foregroundColor: const Color(0xFF16A34A),
      );
    }
    if (diffDays == 0) {
      return TicketDueDateStyle(
        badgeLabel: statusText,
        backgroundColor: const Color(0xFFFFEDD5),
        foregroundColor: const Color(0xFFEA580C),
      );
    }
    if (diffDays == 1) {
      return TicketDueDateStyle(
        badgeLabel: statusText,
        backgroundColor: const Color(0xFFFEF9C3),
        foregroundColor: const Color(0xFFCA8A04),
      );
    }
    if (diffDays <= 3) {
      return TicketDueDateStyle(
        badgeLabel: statusText,
        backgroundColor: const Color(0xFFFEFCE8),
        foregroundColor: const Color(0xFFA16207),
      );
    }
    return TicketDueDateStyle(
      badgeLabel: statusText,
      backgroundColor: const Color(0xFFDCFCE7),
      foregroundColor: const Color(0xFF16A34A),
    );
  }
}

/// Tanggal + badge status SLA (sama pola dengan kolom Due di web).
class TicketDueDateRow extends StatelessWidget {
  final String dueIso;
  final String? statusSlug;
  final String dateLabel;
  final double fontSize;
  final bool showDuePrefix;

  /// Di dalam `Row` + `Flexible` (daftar): [true]. Di `Wrap` (detail): [false].
  final bool expandDateToFit;

  const TicketDueDateRow({
    super.key,
    required this.dueIso,
    required this.dateLabel,
    this.statusSlug,
    this.fontSize = 10,
    this.showDuePrefix = true,
    this.expandDateToFit = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = TicketDueDateStyle.compute(dueIso: dueIso, statusSlug: statusSlug);
    final prefix = showDuePrefix ? 'Due ' : '';

    final dateText = Text(
      '$prefix$dateLabel',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF111827),
      ),
    );

    final gap = SizedBox(width: fontSize >= 11 ? 8 : 6);
    final badge = Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize >= 11 ? 8 : 6, vertical: fontSize >= 11 ? 4 : 3),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: fontSize + 2, color: style.foregroundColor),
          SizedBox(width: fontSize >= 11 ? 4 : 3),
          Text(
            style.badgeLabel,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: style.foregroundColor,
            ),
          ),
        ],
      ),
    );

    if (expandDateToFit) {
      return Row(
        children: [
          Expanded(child: dateText),
          gap,
          badge,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dateText,
        gap,
        badge,
      ],
    );
  }
}
