import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'note.dart';
import 'style.dart';

class EditorPage extends StatefulWidget {
  final Note note;
  final Future<void> Function(Note note) onChanged;
  final Future<void> Function(Note note)? onDelete;

  const EditorPage({
    super.key,
    required this.note,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _c;
  late final FocusNode _focus;
  Timer? _timer;
  bool _preview = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.note.body);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _touch(String text) {
    widget.note.body = text;
    widget.note.updated = DateTime.now();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), _flush);
    setState(() {});
  }

  Future<void> _flush() async {
    _timer?.cancel();
    widget.note.body = _c.text;
    widget.note.updated = DateTime.now();
    await widget.onChanged(widget.note);
  }

  void _wrap(String left, String right, {String placeholder = ''}) {
    final text = _c.text;
    final sel = _c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = sel.isValid ? text.substring(start, end) : '';
    final body = selected.isEmpty ? placeholder : selected;
    final newText = text.replaceRange(start, end, '$left$body$right');
    final cursor = selected.isEmpty
        ? start + left.length + placeholder.length
        : start + left.length + body.length + right.length;
    _c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _touch(newText);
    _focus.requestFocus();
  }

  void _prefixLine(String prefix) {
    final text = _c.text;
    final sel = _c.selection;
    final pos = sel.isValid ? sel.start : text.length;
    var lineStart = 0;
    if (pos > 0) {
      final idx = text.lastIndexOf('\n', pos - 1);
      lineStart = idx + 1;
    }
    if (text.startsWith(prefix, lineStart)) {
      final newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
      _c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (pos - prefix.length).clamp(0, newText.length)),
      );
      _touch(newText);
    } else {
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      _c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
      _touch(newText);
    }
    _focus.requestFocus();
  }

  void _insertBlock(String block) {
    final text = _c.text;
    final sel = _c.selection;
    final pos = sel.isValid ? sel.start : text.length;
    final needsNl = pos > 0 && !text.substring(0, pos).endsWith('\n');
    final insert = '${needsNl ? '\n' : ''}$block';
    final newText = text.replaceRange(pos, pos, insert);
    _c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    _touch(newText);
    _focus.requestFocus();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        title: const Text('删掉这一篇？', style: TextStyle(fontFamily: kSerif)),
        content: Text('删了就在手机里没有了。电脑上已经同步过去的会留着。',
            style: TextStyle(
                fontFamily: kSerif, color: Theme.of(ctx).textTheme.bodySmall?.color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('留着', style: TextStyle(fontFamily: kSerif)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删掉',
                style: TextStyle(
                    fontFamily: kSerif,
                    color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _timer?.cancel();
      _deleted = true;
      await widget.onDelete?.call(widget.note);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _close() async {
    await _flush();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppStyle.palette;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_deleted) {
          _timer?.cancel();
          widget.note.body = _c.text;
          widget.note.updated = DateTime.now();
          widget.onChanged(widget.note);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: p.sub,
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '最后编辑 ${editStamp(widget.note.updated)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSerif, fontSize: 11.5, color: p.faint),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await _flush();
                        setState(() => _preview = !_preview);
                        if (!_preview) _focus.requestFocus();
                      },
                      icon: Icon(
                        _preview
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      color: p.sub,
                      splashRadius: 20,
                    ),
                    if (widget.onDelete != null)
                      IconButton(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: p.sub,
                        splashRadius: 20,
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              Expanded(
                child: _preview
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                        child: MarkdownBody(
                          data: _c.text.trim().isEmpty ? '　' : _c.text,
                          selectable: true,
                          styleSheet: _markdownStyle(p),
                        ),
                      )
                    : TextField(
                        controller: _c,
                        focusNode: _focus,
                        onChanged: _touch,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        cursorColor: p.accent,
                        cursorWidth: 1.5,
                        style: TextStyle(
                          fontFamily: kSerif,
                          fontSize: AppStyle.current.fontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.8,
                          color: p.fg,
                          letterSpacing: 0.3,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(22, 0, 22, 32),
                          hintText: '写点什么',
                          hintStyle: TextStyle(
                            fontFamily: kSerif,
                            fontSize: AppStyle.current.fontSize,
                            height: 1.8,
                            color: p.faint,
                          ),
                        ),
                      ),
              ),
              if (!_preview) _toolbar(p),
            ],
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(Palette p) {
    final base = AppStyle.current.fontSize;
    final body = TextStyle(
        fontFamily: kSerif,
        fontSize: base * 0.92,
        fontWeight: FontWeight.w500,
        height: 1.8,
        color: p.fg);
    return MarkdownStyleSheet(
      p: body,
      a: body.copyWith(decoration: TextDecoration.underline),
      h1: body.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 1.5),
      h2: body.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.5),
      h3: body.copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.5),
      h4: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h5: body.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      h6: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      del: body.copyWith(decoration: TextDecoration.lineThrough, color: p.sub),
      blockquote: body.copyWith(color: p.sub),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.accent, width: 2)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 14),
      listBullet: body,
      code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 15,
          color: p.fg,
          backgroundColor: p.line),
      codeblockDecoration: BoxDecoration(
        color: p.line,
        borderRadius: BorderRadius.circular(4),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line, width: 1)),
      ),
    );
  }

  Widget _toolbar(Palette p) {
    Widget btn(String label, VoidCallback onTap, {bool icon = false, IconData? iconData}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          child: icon && iconData != null
              ? Icon(iconData, size: 19, color: p.sub)
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 16,
                    color: p.sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      btn('#', () => _prefixLine('# ')),
                      btn('##', () => _prefixLine('## ')),
                      btn('B', () => _wrap('**', '**', placeholder: '粗体')),
                      btn('I', () => _wrap('*', '*', placeholder: '斜体')),
                      btn('•', () => _prefixLine('- ')),
                      btn('“', () => _prefixLine('> ')),
                      btn('—', () => _insertBlock('\n---\n')),
                      btn('</>', () => _wrap('`', '`', placeholder: '代码')),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _focus.unfocus(),
                icon: Icon(Icons.keyboard_hide_outlined, size: 18, color: p.faint),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
