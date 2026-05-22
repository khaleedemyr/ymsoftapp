import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/omnichannel_inbox_models.dart';
import '../utils/omni_theme.dart';
import 'omni_emoji_picker_sheet.dart';

class OmnichannelComposer extends StatefulWidget {
  final bool replyMode;
  final bool sending;
  final List<OmniMessageTemplate> templates;
  final OmniConversation conversation;
  final ValueChanged<bool> onModeChanged;
  final Future<void> Function({String? body, String? filePath, String? fileName}) onSend;

  const OmnichannelComposer({
    super.key,
    required this.replyMode,
    required this.sending,
    required this.templates,
    required this.conversation,
    required this.onModeChanged,
    required this.onSend,
  });

  @override
  State<OmnichannelComposer> createState() => _OmnichannelComposerState();
}

class _OmnichannelComposerState extends State<OmnichannelComposer> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _templateOpen = false;
  String _templateQuery = '';

  String? _pendingFilePath;
  String? _pendingFileName;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<OmniMessageTemplate> get _filteredTemplates {
    final q = _templateQuery.trim().toLowerCase();
    if (q.isEmpty) return widget.templates;
    return widget.templates.where((t) {
      final shortcut = (t.shortcut ?? '').toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          shortcut.contains(q) ||
          t.body.toLowerCase().contains(q);
    }).toList();
  }

  void _onTextChanged() {
    if (!widget.replyMode) {
      setState(() => _templateOpen = false);
      return;
    }
    final match = RegExp(r'/([\w\-]*)$').firstMatch(_textCtrl.text);
    setState(() {
      _templateOpen = match != null;
      _templateQuery = match?.group(1) ?? '';
    });
  }

  String _applyTemplateBody(String body) {
    final c = widget.conversation;
    final nama = c.contactName ?? c.title;
    return body
        .replaceAll(RegExp(r'\{\{nama\}\}', caseSensitive: false), nama)
        .replaceAll(RegExp(r'\{\{nomor\}\}', caseSensitive: false), c.displayPhone)
        .replaceAll(RegExp(r'\{\{nama_depan\}\}', caseSensitive: false), c.contactName ?? nama);
  }

  void _applyTemplate(OmniMessageTemplate tpl) {
    final body = _applyTemplateBody(tpl.body);
    final newText = _textCtrl.text.replaceFirst(RegExp(r'/[\w\-]*$'), body);
    setState(() => _templateOpen = false);
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.text = newText;
    _textCtrl.selection = TextSelection.collapsed(offset: newText.length);
    _textCtrl.addListener(_onTextChanged);
    _focusNode.requestFocus();
  }

  Future<void> _openEmojiPicker() async {
    final emoji = await OmniEmojiPickerSheet.show(context);
    if (emoji == null || !mounted) return;
    final text = _textCtrl.text;
    final sel = _textCtrl.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : start;
    final newText = text.replaceRange(start, end, emoji);
    _textCtrl.text = newText;
    _textCtrl.selection = TextSelection.collapsed(offset: start + emoji.length);
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _pendingFilePath = picked.path;
        _pendingFileName = picked.name;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result != null && result.files.single.path != null) {
      final f = result.files.single;
      setState(() {
        _pendingFilePath = f.path;
        _pendingFileName = f.name;
      });
    }
  }

  Future<void> _submit() async {
    if (widget.sending) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _pendingFilePath == null) return;
    if (_templateOpen && _filteredTemplates.isNotEmpty) return;

    await widget.onSend(
      body: text.isEmpty ? null : text,
      filePath: _pendingFilePath,
      fileName: _pendingFileName,
    );

    if (mounted) {
      _textCtrl.clear();
      setState(() {
        _pendingFilePath = null;
        _pendingFileName = null;
        _templateOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _filteredTemplates;
    final isReply = widget.replyMode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: OmniTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _modeChip('Balas', true, isReply),
                    _modeChip('Catatan', false, !isReply),
                  ],
                ),
              ),
              if (_pendingFilePath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: OmniTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 18, color: OmniTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pendingFileName ?? 'Lampiran',
                          style: const TextStyle(fontSize: 13, color: OmniTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _pendingFilePath = null;
                          _pendingFileName = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
              if (_templateOpen && templates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: OmniTheme.border),
                      itemBuilder: (context, i) {
                        final tpl = templates[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            tpl.shortcut != null ? '${tpl.title} /${tpl.shortcut}' : tpl.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            tpl.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: OmniTheme.textSecondary),
                          ),
                          onTap: () => _applyTemplate(tpl),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _iconBtn(Icons.image_outlined, _pickImage),
                  _iconBtn(Icons.attach_file_outlined, _pickFile),
                  _iconBtn(Icons.emoji_emotions_outlined, _openEmojiPicker),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      style: const TextStyle(fontSize: 15, color: OmniTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: isReply ? 'Ketik pesan… (/ template)' : 'Catatan internal…',
                        hintStyle: const TextStyle(color: OmniTheme.textSecondary),
                        filled: true,
                        fillColor: OmniTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    elevation: isReply ? 2 : 0,
                    color: isReply ? OmniTheme.primary : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.sending ? null : _submit,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: widget.sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                isReply ? Icons.send_rounded : Icons.note_add_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool value, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onModeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: OmniTheme.primary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? OmniTheme.primary : OmniTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: OmniTheme.textSecondary, size: 22),
      onPressed: widget.sending ? null : onTap,
    );
  }
}
