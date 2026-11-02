import 'package:flutter/material.dart';

import 'editor_page.dart';
import 'note.dart';
import 'settings_page.dart';
import 'style.dart';
import 'sync.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Note> _notes = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NoteStore.load();
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  Palette get _palette => AppStyle.palette;

  Future<void> _upsert(Note note) async {
    final i = _notes.indexWhere((x) => x.id == note.id);
    if (i >= 0) {
      _notes[i] = note;
    } else {
      _notes.add(note);
    }
    _notes.sort((a, b) => b.updated.compareTo(a.updated));
    if (mounted) setState(() {});
    await NoteStore.save(_notes);
  }

  Future<void> _delete(Note note) async {
    _notes.removeWhere((x) => x.id == note.id);
    if (mounted) setState(() {});
    await NoteStore.save(_notes);
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        title: Text('删掉 $count 篇？',
            style: const TextStyle(fontFamily: kSerif)),
        content: Text('删了就在手机里没有了。电脑上已经同步过去的会留着。',
            style: TextStyle(
                fontFamily: kSerif,
                color: Theme.of(ctx).textTheme.bodySmall?.color)),
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
    if (ok != true || !mounted) return;
    setState(() {
      _notes.removeWhere((n) => _selected.contains(n.id));
      _selected.clear();
      _selecting = false;
    });
    await NoteStore.save(_notes);
  }

  void _enterSelect(String id) {
    setState(() {
      _selecting = true;
      _selected.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _cancelSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _openEditor(Note note) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorPage(
          note: note,
          onChanged: _upsert,
          onDelete: _delete,
        ),
      ),
    );
    if (note.isBlank) {
      _notes.removeWhere((x) => x.id == note.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _newNote() async {
    final note = Note.blank();
    await _openEditor(note);
  }

  Future<void> _openSync() async {
    final p = _palette;
    final serverCtrl = TextEditingController(text: Prefs.server);
    final tokenCtrl = TextEditingController(text: Prefs.token);
    var busy = false;
    var message = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.bg,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> saveConfig() async {
            await Prefs.setServer(serverCtrl.text);
            await Prefs.setToken(tokenCtrl.text);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '同步到电脑',
                  style: TextStyle(
                      fontFamily: kSerif,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.fg),
                ),
                const SizedBox(height: 6),
                Text(
                  '电脑上双击「随笔同步」，把窗口里显示的地址和口令填在这里。',
                  style: TextStyle(
                      fontFamily: kSerif, fontSize: 13, height: 1.6, color: p.sub),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: serverCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: TextStyle(fontFamily: kSerif, fontSize: 15, color: p.fg),
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: 'http://192.168.1.10:8730',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenCtrl,
                  style: TextStyle(fontFamily: kSerif, fontSize: 15, color: p.fg),
                  decoration: const InputDecoration(
                    labelText: '口令',
                    hintText: '六位数',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setSheet(() => busy = true);
                              final r = await SyncClient.ping(serverCtrl.text);
                              setSheet(() {
                                busy = false;
                                message = r.message;
                              });
                            },
                      child: Text('测试连接',
                          style: TextStyle(fontFamily: kSerif, color: p.sub)),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor:
                            Theme.of(ctx).brightness == Brightness.dark
                                ? const Color(0xFF16181C)
                                : const Color(0xFFFBF8F3),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              await saveConfig();
                              setSheet(() {
                                busy = true;
                                message = '';
                              });
                              final r = await SyncClient.push(
                                  Prefs.server, Prefs.token, _notes);
                              setSheet(() {
                                busy = false;
                                message = r.message;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        child: Text(
                          busy ? '同步中…' : '立即同步',
                          style: const TextStyle(fontFamily: kSerif),
                        ),
                      ),
                    ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                        fontFamily: kSerif, fontSize: 13, color: p.sub),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          );
        });
      },
    );

    serverCtrl.dispose();
    tokenCtrl.dispose();
  }

  Widget _header(Palette p) {
    if (_selecting) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
        child: Row(
          children: [
            TextButton(
              onPressed: _cancelSelect,
              child: Text('取消',
                  style: TextStyle(fontFamily: kSerif, color: p.sub)),
            ),
            const Spacer(),
            Text(
              '已选 ${_selected.length} 篇',
              style: TextStyle(fontFamily: kSerif, fontSize: 14, color: p.sub),
            ),
            const Spacer(),
            IconButton(
              onPressed: _selected.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline, size: 21),
              color: p.sub,
              splashRadius: 20,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 10, 4),
      child: Row(
        children: [
          Text(
            '随笔',
            style: TextStyle(
              fontFamily: kSerif,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: p.fg,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => AppStyle.toggleTheme(),
            icon: Icon(
              AppStyle.current.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 19,
            ),
            color: p.sub,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openSync,
            icon: const Icon(Icons.cloud_outlined, size: 21),
            color: p.sub,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune, size: 20),
            color: p.sub,
            splashRadius: 20,
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(p),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : _notes.isEmpty
                      ? Center(
                          child: Text(
                            '这里还是空的',
                            style: TextStyle(
                              fontFamily: kSerif,
                              fontSize: 15,
                              color: p.faint,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 96),
                          itemCount: _notes.length,
                          itemBuilder: (ctx, i) {
                            final n = _notes[i];
                            final sel = _selected.contains(n.id);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {
                                if (_selecting) {
                                  _toggleSelect(n.id);
                                } else {
                                  _enterSelect(n.id);
                                }
                              },
                              onTap: () {
                                if (_selecting) {
                                  _toggleSelect(n.id);
                                } else {
                                  _openEditor(n);
                                }
                              },
                              child: Container(
                                color: sel
                                    ? p.accent.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                padding:
                                    const EdgeInsets.fromLTRB(22, 14, 22, 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title.isEmpty
                                                      ? '无题'
                                                      : n.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily: kSerif,
                                                    fontSize:
                                                        AppStyle.current.fontSize,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.5,
                                                    color: p.fg,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Text(
                                                shortDate(n.updated),
                                                style: TextStyle(
                                                  fontFamily: kSerif,
                                                  fontSize: 11.5,
                                                  color: p.faint,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (n.preview.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              n.preview,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: kSerif,
                                                fontSize: AppStyle
                                                        .current.fontSize *
                                                    0.7,
                                                height: 1.7,
                                                color: p.sub,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8, top: 2),
                                        child: Icon(Icons.check_circle,
                                            size: 18, color: p.accent),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: _newNote,
              child: const Icon(Icons.edit_outlined, size: 21),
            ),
    );
  }
}
