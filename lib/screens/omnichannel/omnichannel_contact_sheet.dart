import 'package:flutter/material.dart';
import '../../models/omnichannel_inbox_models.dart';
import '../../services/omnichannel_inbox_service.dart';
import '../../utils/omni_theme.dart';
import '../../widgets/omni_searchable_multiselect.dart';

/// Panel info kontak (assign, lead, memo) — searchable multiselect seperti web.
class OmnichannelContactSheet extends StatefulWidget {
  final OmniConversation conversation;
  final List<OmniLeadStage> leadStages;
  final List<OmniAssignee> assignableUsers;
  final List<OmniTeamRef> assignableTeams;
  final ValueChanged<OmniConversation> onUpdated;

  const OmnichannelContactSheet({
    super.key,
    required this.conversation,
    required this.leadStages,
    required this.assignableUsers,
    required this.assignableTeams,
    required this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required OmniConversation conversation,
    required List<OmniLeadStage> leadStages,
    required List<OmniAssignee> assignableUsers,
    required List<OmniTeamRef> assignableTeams,
    required ValueChanged<OmniConversation> onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OmnichannelContactSheet(
        conversation: conversation,
        leadStages: leadStages,
        assignableUsers: assignableUsers,
        assignableTeams: assignableTeams,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<OmnichannelContactSheet> createState() => _OmnichannelContactSheetState();
}

class _OmnichannelContactSheetState extends State<OmnichannelContactSheet> {
  final _service = OmnichannelInboxService();
  final _memoCtrl = TextEditingController();
  late OmniConversation _conversation;
  late String _leadStage;
  late Set<int> _userIds;
  late Set<int> _teamIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _leadStage = _conversation.leadStage;
    _memoCtrl.text = _conversation.memo ?? '';
    _userIds = _conversation.assignees.map((a) => a.id).toSet();
    _teamIds = _conversation.assignedTeams.map((t) => t.id).toSet();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await _service.updateConversation(_conversation.id, {
        'lead_stage': _leadStage,
        'memo': _memoCtrl.text.trim(),
        'assigned_user_ids': _userIds.toList(),
        'assigned_team_ids': _teamIds.toList(),
      });
      setState(() => _conversation = updated);
      widget.onUpdated(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pauseAutomation() async {
    try {
      final updated = await _service.pauseAutomation(_conversation.id);
      setState(() => _conversation = updated);
      widget.onUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Otomasi dihentikan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversation;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              c.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary),
            ),
            Text(c.displayPhone, style: const TextStyle(color: OmniTheme.textSecondary)),
            if (c.activeFlowName != null && !c.automationPaused) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Otomasi: ${c.activeFlowName}')),
                    TextButton(onPressed: _pauseAutomation, child: const Text('Hentikan')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Tahap lead', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _leadStage,
              items: widget.leadStages
                  .map((s) => DropdownMenuItem(value: s.value, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _leadStage = v ?? _leadStage),
            ),
            const SizedBox(height: 16),
            OmniSearchableMultiselect<OmniAssignee>(
              label: 'Assign ke (bisa banyak)',
              placeholder: 'Ketik nama untuk mencari...',
              options: widget.assignableUsers,
              selectedIds: _userIds,
              idOf: (u) => u.id,
              titleOf: (u) => u.name,
              subtitleOf: (u) => u.subtitle,
              onChanged: (ids) => setState(() => _userIds = ids),
            ),
            const SizedBox(height: 16),
            OmniSearchableMultiselect<OmniTeamRef>(
              label: 'Tim (opsional)',
              placeholder: 'Pilih tim...',
              options: widget.assignableTeams,
              selectedIds: _teamIds,
              idOf: (t) => t.id,
              titleOf: (t) => t.name,
              subtitleOf: (_) => '',
              onChanged: (ids) => setState(() => _teamIds = ids),
            ),
            const SizedBox(height: 16),
            const Text('Memo CRM', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Catatan internal tentang kontak...',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OmniTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
