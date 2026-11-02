import 'package:flutter/material.dart';

import 'home_page.dart';
import 'style.dart';
import 'sync.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.load();
  await AppStyle.load();
  runApp(const SuibiApp());
}

class SuibiApp extends StatelessWidget {
  const SuibiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StyleData>(
      valueListenable: AppStyle.data,
      builder: (ctx, data, _) {
        return MaterialApp(
          title: '随笔',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(paletteOf(data)),
          home: const HomePage(),
        );
      },
    );
  }
}
