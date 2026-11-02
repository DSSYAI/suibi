import 'package:flutter/material.dart';

import 'style.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StyleData>(
      valueListenable: AppStyle.data,
      builder: (ctx, data, _) {
        final p = paletteOf(data);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: p.sub,
                        splashRadius: 20,
                      ),
                      Text('设置',
                          style: TextStyle(
                              fontFamily: kSerif,
                              fontSize: 16,
                              color: p.fg,
                              letterSpacing: 2)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => AppStyle.reset(),
                        child: Text('恢复默认',
                            style: TextStyle(
                                fontFamily: kSerif, fontSize: 13, color: p.sub)),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      _label('字号', p),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('小',
                              style: TextStyle(
                                  fontFamily: kSerif,
                                  fontSize: 13,
                                  color: p.faint)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: p.accent,
                                inactiveTrackColor: p.line,
                                thumbColor: p.accent,
                                overlayColor: p.accent.withValues(alpha: 0.12),
                                trackHeight: 1.5,
                              ),
                              child: Slider(
                                value: data.fontSize,
                                min: 14,
                                max: 28,
                                divisions: 28,
                                onChanged: (v) => AppStyle.update(
                                    data.copyWith(fontSize: v)),
                              ),
                            ),
                          ),
                          Text('大',
                              style: TextStyle(
                                  fontFamily: kSerif,
                                  fontSize: 20,
                                  color: p.faint)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              data.fontSize.round().toString(),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: kSerif,
                                  fontSize: 13,
                                  color: p.sub),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 22),
                        decoration: BoxDecoration(
                          color: data.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.line),
                        ),
                        child: Text(
                          '下午的光落在桌上，字就慢慢长出来。\n今天要写的东西还没有想好。',
                          style: TextStyle(
                            fontFamily: kSerif,
                            fontSize: data.fontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.8,
                            color: data.fg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _label('纸色', p),
                      const SizedBox(height: 12),
                      _swatches(data.bg, kPaperColors, p, (c) {
                        AppStyle.update(data.copyWith(bg: c));
                      }),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _customButton(ctx, p, '自己调一个纸色', data.bg, (c) {
                          AppStyle.update(data.copyWith(bg: c));
                        }),
                      ),
                      const SizedBox(height: 30),
                      _label('墨色', p),
                      const SizedBox(height: 12),
                      _swatches(data.fg, kInkColors, p, (c) {
                        AppStyle.update(data.copyWith(fg: c));
                      }),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _customButton(ctx, p, '自己调一个墨色', data.fg, (c) {
                          AppStyle.update(data.copyWith(fg: c));
                        }),
                      ),
                      const SizedBox(height: 36),
                      Center(
                        child: Text(
                          '字的大小、纸的颜色、墨的颜色，都只在这个手机上。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: kSerif, fontSize: 12, color: p.faint),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, Palette p) => Text(
        text,
        style: TextStyle(
          fontFamily: kSerif,
          fontSize: 13,
          letterSpacing: 3,
          color: p.sub,
        ),
      );

  Widget _swatches(
      Color current, List<Color> colors, Palette p, ValueChanged<Color> onTap) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: colors.map((c) {
        final selected = c.toARGB32() == current.toARGB32();
        return GestureDetector(
          onTap: () => onTap(c),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(
                color: selected ? p.accent : p.line,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _customButton(BuildContext context, Palette p, String text,
      Color initial, ValueChanged<Color> onPick) {
    return TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      onPressed: () async {
        final c = await showColorDialog(context, initial, p);
        if (c != null) onPick(c);
      },
      child: Text(text,
          style: TextStyle(
              fontFamily: kSerif,
              fontSize: 13,
              color: p.accent,
              decoration: TextDecoration.underline)),
    );
  }
}

Future<Color?> showColorDialog(
    BuildContext context, Color initial, Palette p) {
  var r = (initial.r * 255).round();
  var g = (initial.g * 255).round();
  var b = (initial.b * 255).round();

  return showDialog<Color>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setDialog) {
        final color = Color.fromARGB(255, r, g, b);
        Widget slider(String name, int value, ValueChanged<int> onChanged) {
          return Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(name,
                    style: TextStyle(
                        fontFamily: kSerif, fontSize: 13, color: p.sub)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: p.accent,
                    inactiveTrackColor: p.line,
                    thumbColor: p.accent,
                    trackHeight: 1.5,
                  ),
                  child: Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 255,
                    onChanged: (v) => setDialog(() => onChanged(v.round())),
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text('$value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: kSerif, fontSize: 12, color: p.faint)),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: p.bg,
          title: Text('调颜色',
              style: TextStyle(
                  fontFamily: kSerif, fontSize: 16, color: p.fg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.line),
                ),
                child: Text('字',
                    style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 20,
                        color: color.computeLuminance() < 0.5
                            ? Colors.white
                            : Colors.black)),
              ),
              const SizedBox(height: 10),
              slider('R', r, (v) => r = v),
              slider('G', g, (v) => g = v),
              slider('B', b, (v) => b = v),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('算了',
                  style: TextStyle(fontFamily: kSerif, color: p.sub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, color),
              child: Text('就用这个',
                  style: TextStyle(fontFamily: kSerif, color: p.accent)),
            ),
          ],
        );
      });
    },
  );
}
