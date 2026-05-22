import 'package:flutter/material.dart';
import '../utils/omni_theme.dart';
import 'omni_emoji_picker_sheet.dart';

/// Baris balas komentar IG/FB: @ tag + emoji picker + kirim (selaras web).
class OmniCommentReplyBar extends StatefulWidget {
  final TextEditingController controller;
  final Color accent;
  final String? mentionUsername;
  final bool busy;
  final VoidCallback onSend;

  const OmniCommentReplyBar({
    super.key,
    required this.controller,
    required this.accent,
    this.mentionUsername,
    required this.busy,
    required this.onSend,
  });

  @override
  State<OmniCommentReplyBar> createState() => _OmniCommentReplyBarState();
}

class _OmniCommentReplyBarState extends State<OmniCommentReplyBar> {
  final _focusNode = FocusNode();

  String? get _mentionHandle {
    final u = (widget.mentionUsername ?? '').trim().replaceAll(RegExp(r'^@+'), '').replaceAll(RegExp(r'\s+'), '');
    if (u.isEmpty || u.toLowerCase() == 'pengguna') return null;
    return u;
  }

  void _insertAtCursor(String text) {
    final ctrl = widget.controller;
    final value = ctrl.text;
    final sel = ctrl.selection;
    final start = sel.start >= 0 ? sel.start : value.length;
    final end = sel.end >= 0 ? sel.end : start;
    final newText = value.replaceRange(start, end, text);
    ctrl.text = newText;
    ctrl.selection = TextSelection.collapsed(offset: start + text.length);
    _focusNode.requestFocus();
  }

  void _insertMention() {
    final handle = _mentionHandle;
    if (handle == null) return;
    _insertAtCursor('@$handle ');
  }

  Future<void> _openEmojiPicker() async {
    final emoji = await OmniEmojiPickerSheet.show(context);
    if (emoji == null || !mounted) return;
    _insertAtCursor(emoji);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canMention = _mentionHandle != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Balas komentar…',
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 72, 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: canMention && !widget.busy ? _insertMention : null,
          icon: const Icon(Icons.alternate_email_rounded, size: 20),
          color: OmniTheme.textSecondary,
          tooltip: 'Tag pengguna',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: widget.busy ? null : _openEmojiPicker,
          icon: const Icon(Icons.emoji_emotions_outlined, size: 22),
          color: OmniTheme.textSecondary,
          tooltip: 'Emoji',
          visualDensity: VisualDensity.compact,
        ),
        IconButton.filled(
          onPressed: widget.busy ? null : widget.onSend,
          icon: widget.busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 20),
          style: IconButton.styleFrom(backgroundColor: widget.accent),
        ),
      ],
    );
  }
}
