import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'note.dart';

class Prefs {
  static const _kDark = 'dark';
  static const _kServer = 'server';
  static const _kToken = 'token';

  static bool dark = false;
  static String server = '';
  static String token = '';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    dark = p.getBool(_kDark) ?? false;
    server = p.getString(_kServer) ?? '';
    token = p.getString(_kToken) ?? '';
  }

  static Future<void> setDark(bool v) async {
    dark = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDark, v);
  }

  static Future<void> setServer(String v) async {
    server = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, server);
  }

  static Future<void> setToken(String v) async {
    token = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
  }
}

class SyncResult {
  final bool ok;
  final String message;
  const SyncResult(this.ok, this.message);
}

class SyncClient {
  static String _norm(String base) {
    var s = base.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static Future<SyncResult> ping(String base) async {
    try {
      final r = await http
          .get(Uri.parse('${_norm(base)}/ping'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['app'] == 'suibi') {
          return const SyncResult(true, '通了');
        }
        return const SyncResult(false, '有响应，但不是随笔的同步程序');
      }
      return SyncResult(false, 'HTTP ${r.statusCode}');
    } catch (e) {
      return SyncResult(false, '连不上：$e');
    }
  }

  static Future<SyncResult> push(
      String base, String token, List<Note> notes) async {
    try {
      final body = jsonEncode({
        'token': token,
        'notes': notes.map((n) => n.toJson()).toList(),
      });
      final r = await http
          .post(
            Uri.parse('${_norm(base)}/sync'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true) {
          return SyncResult(true, '已同步 ${j['written'] ?? 0} 条');
        }
        return SyncResult(false, '${j['error'] ?? '未知错误'}');
      }
      if (r.statusCode == 401) {
        return const SyncResult(false, '口令不对');
      }
      return SyncResult(false, 'HTTP ${r.statusCode}');
    } catch (e) {
      return SyncResult(false, '同步失败：$e');
    }
  }
}
