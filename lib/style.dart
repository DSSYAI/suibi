import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kSerif = 'NotoSerifSC';

class Palette {
  final Color bg;
  final Color fg;
  final Color sub;
  final Color faint;
  final Color line;
  final Color accent;

  const Palette({
    required this.bg,
    required this.fg,
    required this.sub,
    required this.faint,
    required this.line,
    required this.accent,
  });
}

/// 用户在设置里调的东西：字号、纸色、墨色。
class StyleData {
  final double fontSize;
  final Color bg;
  final Color fg;

  const StyleData({
    required this.fontSize,
    required this.bg,
    required this.fg,
  });

  static const paper = StyleData(
    fontSize: 19,
    bg: Color(0xFFFAF7F2),
    fg: Color(0xFF17140F),
  );

  static const night = StyleData(
    fontSize: 19,
    bg: Color(0xFF14171C),
    fg: Color(0xFFF0EBE2),
  );

  bool get isDark => bg.computeLuminance() < 0.5;

  StyleData copyWith({double? fontSize, Color? bg, Color? fg}) => StyleData(
        fontSize: fontSize ?? this.fontSize,
        bg: bg ?? this.bg,
        fg: fg ?? this.fg,
      );
}

Palette paletteOf(StyleData d) {
  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;
  final dark = d.isDark;
  return Palette(
    bg: d.bg,
    fg: d.fg,
    sub: mix(d.fg, d.bg, dark ? 0.35 : 0.38),
    faint: mix(d.fg, d.bg, dark ? 0.60 : 0.58),
    line: mix(d.fg, d.bg, 0.86),
    accent: dark ? const Color(0xFFC9A87C) : const Color(0xFF8C6E4A),
  );
}

class AppStyle {
  static final ValueNotifier<StyleData> data =
      ValueNotifier<StyleData>(StyleData.paper);

  static StyleData get current => data.value;
  static Palette get palette => paletteOf(data.value);

  static const _kSize = 'style.fontSize';
  static const _kBg = 'style.bg';
  static const _kFg = 'style.fg';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    data.value = StyleData(
      fontSize: (p.getDouble(_kSize) ?? StyleData.paper.fontSize)
          .clamp(13.0, 30.0),
      bg: Color(p.getInt(_kBg) ?? StyleData.paper.bg.toARGB32()),
      fg: Color(p.getInt(_kFg) ?? StyleData.paper.fg.toARGB32()),
    );
  }

  static Future<void> update(StyleData d) async {
    data.value = d;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSize, d.fontSize);
    await p.setInt(_kBg, d.bg.toARGB32());
    await p.setInt(_kFg, d.fg.toARGB32());
  }

  static Future<void> toggleTheme() async {
    final d = current;
    final target = d.isDark ? StyleData.paper : StyleData.night;
    await update(d.copyWith(bg: target.bg, fg: target.fg));
  }

  static Future<void> reset() async {
    await update(StyleData.paper);
  }
}

/// 常用的纸色、墨色。
const List<Color> kPaperColors = [
  Color(0xFFFAF7F2),
  Color(0xFFFFFFFF),
  Color(0xFFF5F0E6),
  Color(0xFFEEF1F4),
  Color(0xFFF2EDE4),
  Color(0xFF1B1B1D),
  Color(0xFF14171C),
  Color(0xFF10151C),
  Color(0xFF1D1A17),
  Color(0xFF2A2622),
];

const List<Color> kInkColors = [
  Color(0xFF17140F),
  Color(0xFF000000),
  Color(0xFF3A2E22),
  Color(0xFF1F2A3A),
  Color(0xFF2E3230),
  Color(0xFF5A3B2E),
  Color(0xFFF0EBE2),
  Color(0xFFE8D9B8),
  Color(0xFFCFC7BA),
  Color(0xFF8A8F96),
];
