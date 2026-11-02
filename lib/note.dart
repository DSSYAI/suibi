import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class Note {
  final String id;
  String body;
  DateTime created;
  DateTime updated;

  Note({
    required this.id,
    required this.body,
    required this.created,
    required this.updated,
  });

  factory Note.blank() {
    final now = DateTime.now();
    return Note(
      id: '${now.microsecondsSinceEpoch}-${now.hashCode}',
      body: '',
      created: now,
      updated: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'created': created.millisecondsSinceEpoch,
        'updated': updated.millisecondsSinceEpoch,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        body: (j['body'] as String?) ?? '',
        created: DateTime.fromMillisecondsSinceEpoch(
            (j['created'] as num?)?.toInt() ?? 0),
        updated: DateTime.fromMillisecondsSinceEpoch(
            (j['updated'] as num?)?.toInt() ?? 0),
      );

  /// 第一行非空文字，去掉 markdown 记号，当标题用。
  String get title {
    for (final raw in body.split('\n')) {
      var t = raw.trim();
      if (t.isEmpty) continue;
      t = t.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
      t = t.replaceFirst(RegExp(r'^(\s*([-*+>]|\d+[.)])\s+)+'), '');
      t = t.replaceAll(RegExp(r'(\*\*|__|`|~~)'), '');
      t = t.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  /// 标题之后的一小段，列表里当摘要。
  String get preview {
    var seenTitle = false;
    final buf = StringBuffer();
    for (final raw in body.split('\n')) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (!seenTitle) {
        seenTitle = true;
        continue;
      }
      buf.write(t.replaceAll(RegExp(r'[#>*_`~]'), ''));
      buf.write(' ');
      if (buf.length > 60) break;
    }
    final s = buf.toString().trim();
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  bool get isBlank => body.trim().isEmpty;
}

String two(int v) => v.toString().padLeft(2, '0');

String shortDate(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days == 0) return '${two(d.hour)}:${two(d.minute)}';
  if (days == 1) return '昨天';
  if (now.year == d.year && days < 7) return '${d.month}月${d.day}日';
  return '${d.year}年${d.month}月${d.day}日';
}

String longDate(DateTime d) =>
    '${d.year} 年 ${d.month} 月 ${d.day} 日  ${two(d.hour)}:${two(d.minute)}';

/// 编辑页顶栏用：今天只显示时分，隔了几天就补上年月日。
String editStamp(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  final hm = '${two(d.hour)}:${two(d.minute)}';
  if (days == 0) return hm;
  if (days == 1) return '昨天 $hm';
  if (now.year == d.year && days < 7) return '${d.month}月${d.day}日 $hm';
  return '${d.year}年${d.month}月${d.day}日';
}

class NoteStore {
  static File? _file;

  static Future<File> _fileRef() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}notes.json');
    return _file!;
  }

  static Future<List<Note>> load() async {
    try {
      final f = await _fileRef();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final data = jsonDecode(raw);
      final list = (data['notes'] as List?) ?? const [];
      final notes = list
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();
      notes.sort((a, b) => b.updated.compareTo(a.updated));
      return notes;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Note> notes) async {
    final f = await _fileRef();
    final payload = jsonEncode({
      'version': 1,
      'notes': notes.map((n) => n.toJson()).toList(),
    });
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(f.path);
  }
}
