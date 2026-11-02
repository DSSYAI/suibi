import 'package:flutter/material.dart';

import 'style.dart';

ThemeData buildTheme(Palette p) {
  final dark = p.bg.computeLuminance() < 0.5;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
  );

  final text = base.textTheme
      .apply(fontFamily: kSerif, bodyColor: p.fg, displayColor: p.fg);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: p.accent,
      surface: p.bg,
      onSurface: p.fg,
    ),
    textTheme: text,
    iconTheme: IconThemeData(color: p.sub, size: 22),
    dividerColor: p.line,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.fg,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
      focusedBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: p.accent)),
      hintStyle: TextStyle(color: p.faint, fontFamily: kSerif),
      labelStyle: TextStyle(color: p.sub, fontFamily: kSerif),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: dark ? const Color(0xFF16181C) : const Color(0xFFFBF8F3),
      elevation: 0,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.fg,
      contentTextStyle: TextStyle(color: p.bg, fontFamily: kSerif, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
