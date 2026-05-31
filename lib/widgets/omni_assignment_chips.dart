import 'package:flutter/material.dart';
import '../models/omnichannel_inbox_models.dart';

enum OmniAssignmentChipStyle { header, list }

/// Chip ringkas untuk assignee user & tim — selaras tampilan web inbox.
class OmniAssignmentChips extends StatelessWidget {
  final List<OmniAssignee> assignees;
  final List<OmniTeamRef> teams;
  final OmniAssignmentChipStyle style;
  final int maxAssignees;
  final int maxTeams;

  const OmniAssignmentChips({
    super.key,
    required this.assignees,
    required this.teams,
    this.style = OmniAssignmentChipStyle.list,
    this.maxAssignees = 2,
    this.maxTeams = 2,
  });

  bool get _isEmpty => assignees.isEmpty && teams.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) return const SizedBox.shrink();

    final isHeader = style == OmniAssignmentChipStyle.header;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (assignees.isNotEmpty) ...[
          Icon(
            Icons.person_outline_rounded,
            size: 12,
            color: isHeader ? Colors.white70 : Colors.indigo.shade700,
          ),
          ...assignees.take(maxAssignees).map((a) => _assigneeChip(context, a, isHeader)),
          if (assignees.length > maxAssignees)
            _overflowChip(
              context,
              '+${assignees.length - maxAssignees}',
              _assigneesTooltip(assignees),
              isHeader,
              isUser: true,
            ),
        ],
        if (teams.isNotEmpty) ...[
          Icon(
            Icons.groups_outlined,
            size: 12,
            color: isHeader ? Colors.white70 : Colors.lightBlue.shade800,
          ),
          ...teams.take(maxTeams).map((t) => _teamChip(context, t, isHeader)),
          if (teams.length > maxTeams)
            _overflowChip(
              context,
              '+${teams.length - maxTeams}',
              teams.map((t) => t.name).join('\n'),
              isHeader,
              isUser: false,
            ),
        ],
      ],
    );
  }

  Widget _assigneeChip(BuildContext context, OmniAssignee assignee, bool isHeader) {
    final label = assignee.name.trim().isEmpty ? 'User' : assignee.name.trim();
    final tooltip = assignee.mentionLabel;

    return _chip(
      context: context,
      label: label,
      tooltip: tooltip,
      isHeader: isHeader,
      isUser: true,
    );
  }

  Widget _teamChip(BuildContext context, OmniTeamRef team, bool isHeader) {
    return _chip(
      context: context,
      label: team.name,
      tooltip: team.name,
      isHeader: isHeader,
      isUser: false,
    );
  }

  Widget _chip({
    required BuildContext context,
    required String label,
    required String tooltip,
    required bool isHeader,
    required bool isUser,
  }) {
    final bg = isHeader
        ? Colors.white.withValues(alpha: 0.18)
        : (isUser ? Colors.indigo.shade50 : Colors.lightBlue.shade50);
    final fg = isHeader
        ? Colors.white
        : (isUser ? Colors.indigo.shade800 : Colors.lightBlue.shade900);
    final border = isHeader
        ? Colors.white.withValues(alpha: 0.25)
        : (isUser ? Colors.indigo.shade100 : Colors.lightBlue.shade100);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _overflowChip(
    BuildContext context,
    String label,
    String tooltip,
    bool isHeader, {
    required bool isUser,
  }) {
    final bg = isHeader
        ? Colors.white.withValues(alpha: 0.28)
        : (isUser ? Colors.indigo.shade100 : Colors.lightBlue.shade100);
    final fg = isHeader
        ? Colors.white
        : (isUser ? Colors.indigo.shade900 : Colors.lightBlue.shade900);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  String _assigneesTooltip(List<OmniAssignee> list) {
    return list.map((a) => a.mentionLabel).join('\n');
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penugasan chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (assignees.isNotEmpty) ...[
                  Text(
                    'User',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...assignees.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person_outline, size: 18, color: Colors.indigo.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (a.subtitle.isNotEmpty)
                                  Text(
                                    a.subtitle,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (teams.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tim',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.lightBlue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...teams.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.groups_outlined, size: 18, color: Colors.lightBlue.shade400),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
