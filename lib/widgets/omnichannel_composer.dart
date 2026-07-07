import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/omnichannel_inbox_models.dart';
import '../services/omnichannel_inbox_service.dart';
import '../utils/omni_chat_spellfix.dart';
import '../utils/omni_theme.dart';
import 'omni_emoji_picker_sheet.dart';

const _lsAutoGrammar = 'omni_inbox_auto_grammar_send';

class _PendingComposerFile {
  const _PendingComposerFile({required this.path, required this.name, required this.isImage});

  final String path;
  final String name;
  final bool isImage;
}

class OmnichannelComposer extends StatefulWidget {
  final bool replyMode;
  final bool sending;
  final List<OmniMessageTemplate> templates;
  final List<OmniAssignee> assignableUsers;
  final OmniConversation conversation;
  final bool aiWritingEnabled;
  final bool composerSpellcheck;
  final bool autoGrammarOnSendDefault;
  final int autoGrammarMaxChars;
  final int autoGrammarMinChars;
  final ValueChanged<bool> onModeChanged;
  final Future<void> Function({
    String? body,
    List<String> filePaths,
    List<String> fileNames,
    List<int> mentionedUserIds,
  }) onSend;

  const OmnichannelComposer({
    super.key,
    required this.replyMode,
    required this.sending,
    required this.templates,
    required this.assignableUsers,
    required this.conversation,
    required this.onModeChanged,
    required this.onSend,
    this.aiWritingEnabled = true,
    this.composerSpellcheck = true,
    this.autoGrammarOnSendDefault = true,
    this.autoGrammarMaxChars = 2500,
    this.autoGrammarMinChars = 4,
  });

  @override
  State<OmnichannelComposer> createState() => OmnichannelComposerState();
}

class OmnichannelComposerState extends State<OmnichannelComposer> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _service = OmnichannelInboxService();
  bool _templateOpen = false;
  String _templateQuery = '';
  bool _mentionMenuOpen = false;
  String _mentionQuery = '';
  int _mentionHighlight = 0;
  final Set<int> _mentionUserIds = {};
  bool _autoGrammarOnSend = true;
  bool _grammarChecking = false;
  OmniMessage? _replyTarget;

  final List<_PendingComposerFile> _pendingFiles = [];

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
    _autoGrammarOnSend = widget.autoGrammarOnSendDefault;
    _loadAutoGrammarPref();
  }

  Future<void> _loadAutoGrammarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.containsKey(_lsAutoGrammar)) {
      setState(() => _autoGrammarOnSend = prefs.getBool(_lsAutoGrammar) ?? widget.autoGrammarOnSendDefault);
    }
  }

  Future<void> _saveAutoGrammarPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lsAutoGrammar, value);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _messageSnippet(OmniMessage msg) {
    final body = msg.body.trim();
    if (body.isNotEmpty && !const {'[Gambar]', '[Lampiran]', '[Video]', '[Audio]', '[Berkas]', '[Dokumen]'}.contains(body)) {
      return body;
    }
    final type = (msg.messageType ?? '').toLowerCase();
    if (type == 'image') return '[Gambar]';
    if (type == 'video') return '[Video]';
    if (type == 'audio') return '[Audio]';
    if (type == 'document' || type == 'attachment') {
      if ((msg.mediaFilename ?? '').isNotEmpty) return '[Dokumen: ${msg.mediaFilename}]';
      return '[Dokumen]';
    }
    return body.isNotEmpty ? body : '[Lampiran]';
  }

  String _replyTargetLabel(OmniMessage msg) {
    if (msg.isOutbound) return msg.authorName ?? 'tim';
    return widget.conversation.contactName?.trim().isNotEmpty == true
        ? widget.conversation.contactName!.trim()
        : widget.conversation.displayPhone;
  }

  void prepareReplyFromMessage(OmniMessage msg) {
    if (!mounted) return;
    setState(() {
      _replyTarget = msg;
    });
    _focusNode.requestFocus();
  }

  void prepareForwardFromMessage(OmniMessage msg) {
    if (!mounted) return;
    final snippet = _messageSnippet(msg);
    setState(() {
      _replyTarget = null;
      _pendingFiles.clear();
      _textCtrl.text = snippet.isNotEmpty ? '↪️ Forwarded message\n$snippet' : '↪️ Forwarded message';
      _textCtrl.selection = TextSelection.collapsed(offset: _textCtrl.text.length);
    });
    _focusNode.requestFocus();
  }

  void clearReplyTarget() {
    if (!mounted) return;
    setState(() => _replyTarget = null);
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

  List<OmniAssignee> get _filteredMentionUsers {
    final q = _mentionQuery.trim().toLowerCase();
    final list = widget.assignableUsers;
    if (q.isEmpty) return list.take(12).toList();
    return list
        .where((u) {
          final hay = '${u.name} ${u.jabatan ?? ''} ${u.outlet ?? ''}'.toLowerCase();
          return hay.contains(q);
        })
        .take(12)
        .toList();
  }

  void _onTextChanged() {
    final text = _textCtrl.text;
    if (!widget.replyMode) {
      final mentionMatch = RegExp(r'@([^\n@]*)$').firstMatch(text);
      setState(() {
        _templateOpen = false;
        _mentionMenuOpen = mentionMatch != null;
        _mentionQuery = mentionMatch?.group(1) ?? '';
        _mentionHighlight = 0;
      });
      return;
    }
    final match = RegExp(r'/([\w\-]*)$').firstMatch(text);
    setState(() {
      _templateOpen = match != null;
      _templateQuery = match?.group(1) ?? '';
      _mentionMenuOpen = false;
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

  void _applyMention(OmniAssignee user) {
    final text = _textCtrl.text;
    final newText = text.replaceFirst(RegExp(r'@[^\n@]*$'), '@${user.name} ');
    _mentionUserIds.add(user.id);
    setState(() {
      _mentionMenuOpen = false;
      _mentionQuery = '';
    });
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

  void _addPendingImages(List<XFile> picked) {
    if (picked.isEmpty) return;
    final room = OmnichannelInboxService.maxAttachments - _pendingFiles.length;
    if (room <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maksimal ${OmnichannelInboxService.maxAttachments} gambar per kirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final toAdd = picked.take(room).toList();
    if (picked.length > room) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hanya ${room} gambar ditambahkan (maks. ${OmnichannelInboxService.maxAttachments}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {
      _pendingFiles.addAll(
        toAdd.map((f) => _PendingComposerFile(path: f.path, name: f.name, isImage: true)),
      );
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (!mounted) return;
    _addPendingImages(picked);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result != null && result.files.single.path != null) {
      final f = result.files.single;
      setState(() {
        _pendingFiles
          ..clear()
          ..add(_PendingComposerFile(
            path: f.path!,
            name: f.name,
            isImage: false,
          ));
      });
    }
  }

  void _removePendingFile(int index) {
    setState(() => _pendingFiles.removeAt(index));
  }

  void _clearPendingFiles() {
    setState(() => _pendingFiles.clear());
  }

  bool _grammarTextsDiffer(String original, String corrected) {
    final a = original.trim();
    final b = corrected.trim();
    if (a == b) return false;
    final normalize = (String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return normalize(a) != normalize(b);
  }

  Future<String?> _showGrammarChoiceDialog({
    required String original,
    required String corrected,
  }) {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        final maxPreviewHeight = MediaQuery.sizeOf(ctx).height * 0.35;
        return AlertDialog(
          title: const Text('Perbaikan ejaan disarankan'),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width * 0.88,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pilih versi yang akan dikirim ke pelanggan:',
                    style: TextStyle(fontSize: 13, color: OmniTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text('Asli', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OmniTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    constraints: BoxConstraints(maxHeight: maxPreviewHeight),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: OmniTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OmniTheme.border),
                    ),
                    child: SingleChildScrollView(child: Text(original, style: const TextStyle(fontSize: 14, height: 1.4))),
                  ),
                  const SizedBox(height: 10),
                  Text('Disarankan AI', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                  const SizedBox(height: 4),
                  Container(
                    constraints: BoxConstraints(maxHeight: maxPreviewHeight),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.35)),
                    ),
                    child: SingleChildScrollView(child: Text(corrected, style: const TextStyle(fontSize: 14, height: 1.4))),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'original'), child: const Text('Kirim asli')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'corrected'),
              child: const Text('Perbaiki ejaan'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showGrammarFailedDialog(String message) {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Periksa ejaan gagal'),
        content: Text('$message\n\nTetap kirim teks asli?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'original'), child: const Text('Kirim asli')),
        ],
      ),
    );
  }

  Future<String?> _resolveGrammarSuggestion(String trimmed, {bool quickOnly = false}) async {
    final ruleFixed = OmniChatSpellfix.apply(trimmed);

    if (!quickOnly && widget.aiWritingEnabled) {
      try {
        final aiResult = await _service.aiAssistGrammar(trimmed);
        if (_grammarTextsDiffer(trimmed, aiResult)) return aiResult;
      } catch (_) {
        // fallback ke rule-based di bawah
      }
    }

    if (_grammarTextsDiffer(trimmed, ruleFixed)) return ruleFixed;
    return null;
  }

  Future<String?> _maybeGrammarCorrect(String text) async {
    if (!widget.replyMode || !_autoGrammarOnSend) return text;
    if (_pendingFiles.isNotEmpty) return text;
    final trimmed = text.trim();
    if (trimmed.length < widget.autoGrammarMinChars || trimmed.length > widget.autoGrammarMaxChars) {
      return text;
    }
    setState(() => _grammarChecking = true);
    try {
      final corrected = await _resolveGrammarSuggestion(trimmed, quickOnly: true);
      if (!mounted) return null;
      if (corrected == null) return text;

      final choice = await _showGrammarChoiceDialog(original: trimmed, corrected: corrected);
      if (!mounted) return null;
      if (choice == 'corrected') return corrected;
      if (choice == 'original') return text;
      return null;
    } catch (e) {
      if (!mounted) return null;
      final message = e.toString().replaceFirst('Exception: ', '');
      final fallback = await _showGrammarFailedDialog(message);
      if (!mounted) return null;
      if (fallback == 'original') return text;
      return null;
    } finally {
      if (mounted) setState(() => _grammarChecking = false);
    }
  }

  Future<void> _runGrammarNow() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || !widget.aiWritingEnabled) return;
    setState(() => _grammarChecking = true);
    try {
      final corrected = await _service.aiAssistGrammar(text);
      if (!mounted) return;
      if (corrected != text) {
        _textCtrl.text = corrected;
        _textCtrl.selection = TextSelection.collapsed(offset: corrected.length);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada perubahan ejaan'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _grammarChecking = false);
    }
  }

  Future<void> _submit() async {
    if (widget.sending || _grammarChecking) return;
    var text = _textCtrl.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;
    if (_templateOpen && _filteredTemplates.isNotEmpty) return;
    if (_mentionMenuOpen && _filteredMentionUsers.isNotEmpty) return;

    if (widget.replyMode && text.isNotEmpty) {
      final corrected = await _maybeGrammarCorrect(text);
      if (corrected == null) return;
      text = corrected;
    }

    if (widget.replyMode && _replyTarget != null) {
      final label = _replyTargetLabel(_replyTarget!);
      final snippet = _messageSnippet(_replyTarget!);
      final quote = '↪️ Reply ke $label\n> ${snippet.split('\n').join('\n> ')}';
      text = text.isNotEmpty ? '$quote\n\n$text' : quote;
    }

    await widget.onSend(
      body: text.isEmpty ? null : text,
      filePaths: _pendingFiles.map((f) => f.path).toList(),
      fileNames: _pendingFiles.map((f) => f.name).toList(),
      mentionedUserIds: widget.replyMode ? [] : _mentionUserIds.toList(),
    );

    if (mounted) {
      _textCtrl.clear();
      setState(() {
        _pendingFiles.clear();
        _templateOpen = false;
        _mentionMenuOpen = false;
        _mentionUserIds.clear();
        _replyTarget = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _filteredTemplates;
    final mentionUsers = _filteredMentionUsers;
    final isReply = widget.replyMode;
    final busy = widget.sending || _grammarChecking;

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
              if (isReply && widget.aiWritingEnabled) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Checkbox(
                        value: _autoGrammarOnSend,
                        activeColor: OmniTheme.primary,
                        onChanged: busy
                            ? null
                            : (v) {
                                final next = v ?? false;
                                setState(() => _autoGrammarOnSend = next);
                                _saveAutoGrammarPref(next);
                              },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: busy
                            ? null
                            : () {
                                final next = !_autoGrammarOnSend;
                                setState(() => _autoGrammarOnSend = next);
                                _saveAutoGrammarPref(next);
                              },
                        child: Text(
                          'Perbaiki typo otomatis saat kirim',
                          style: TextStyle(fontSize: 12, color: OmniTheme.textSecondary.withValues(alpha: 0.95)),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : _runGrammarNow,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: OmniTheme.primary,
                      ),
                      child: const Text('Perbaiki ejaan', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
              if (!isReply && _mentionUserIds.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _mentionUserIds.map((id) {
                      final u = widget.assignableUsers.firstWhere(
                        (a) => a.id == id,
                        orElse: () => OmniAssignee(id: id, name: '#$id'),
                      );
                      return Chip(
                        label: Text(u.name, style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(() => _mentionUserIds.remove(id)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.amber.shade50,
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (isReply && _replyTarget != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Membalas ${_replyTargetLabel(_replyTarget!)}\n${_messageSnippet(_replyTarget!)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Batal reply',
                        visualDensity: VisualDensity.compact,
                        onPressed: clearReplyTarget,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
              if (_pendingFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: OmniTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_pendingFiles.length} lampiran'
                              '${_pendingFiles.length >= OmnichannelInboxService.maxAttachments ? ' (maks.)' : ''}',
                              style: const TextStyle(fontSize: 12, color: OmniTheme.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearPendingFiles,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text('Hapus semua', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_pendingFiles.length, (i) {
                          final file = _pendingFiles[i];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: OmniTheme.border),
                                ),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                      child: file.isImage
                                          ? Image.file(
                                              File(file.path),
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 72,
                                              height: 72,
                                              color: OmniTheme.surface,
                                              child: const Icon(Icons.insert_drive_file, color: OmniTheme.primary),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        file.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 9, color: OmniTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Material(
                                  color: const Color(0xFF334155),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _removePendingFile(i),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
              if (_templateOpen && templates.isNotEmpty) ...[
                const SizedBox(height: 8),
                _dropdownList(
                  templates.length,
                  (i) {
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
              ],
              if (_mentionMenuOpen && mentionUsers.isNotEmpty) ...[
                const SizedBox(height: 8),
                _dropdownList(
                  mentionUsers.length,
                  (i) {
                    final u = mentionUsers[i];
                    final selected = i == _mentionHighlight;
                    return ListTile(
                      dense: true,
                      tileColor: selected ? Colors.amber.shade50 : null,
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: u.subtitle.isNotEmpty
                          ? Text(u.subtitle, style: const TextStyle(fontSize: 12, color: OmniTheme.textSecondary))
                          : null,
                      onTap: () => _applyMention(u),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _iconBtn(Icons.image_outlined, _pickImage, tooltip: 'Gambar (bisa beberapa)'),
                  _iconBtn(Icons.attach_file_outlined, _pickFile),
                  _iconBtn(Icons.emoji_emotions_outlined, _openEmojiPicker),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      enableSuggestions: widget.composerSpellcheck,
                      autocorrect: widget.composerSpellcheck,
                      style: const TextStyle(fontSize: 15, color: OmniTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: isReply
                            ? 'Ketik pesan… (/ template)'
                            : 'Catatan internal… (@ tag user)',
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
                      onTap: busy ? null : _submit,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: busy
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

  Widget _dropdownList(int count, Widget Function(int) itemBuilder) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: count,
          separatorBuilder: (_, __) => const Divider(height: 1, color: OmniTheme.border),
          itemBuilder: (context, i) => itemBuilder(i),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool value, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mentionMenuOpen = false;
            _templateOpen = false;
            if (!value) {
              _replyTarget = null;
            }
          });
          widget.onModeChanged(value);
        },
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

  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      icon: Icon(icon, color: OmniTheme.textSecondary, size: 22),
      onPressed: widget.sending || _grammarChecking ? null : onTap,
    );
  }
}
