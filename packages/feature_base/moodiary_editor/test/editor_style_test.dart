// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    TranslationProvider(
      child: MaterialApp(
        theme: buildMuiTheme(brightness: brightness),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        builder: (context, child) =>
            MaterialUiCompatibilityBridge(child: child!),
        home: Scaffold(body: child),
      ),
    );
void main() {
  test(
    'font metrics are explicit at scale 1 and headings never inherit tracking',
    () {
      final s = buildEditorStyle(brightness: Brightness.light);
      expect(s.paragraph.fontSize, 17);
      expect(s.paragraph.fontWeight, FontWeight.w400);
      expect(s.paragraph.height, 1.65);
      expect(s.paragraph.letterSpacing, 0);
      expect(s.paragraph.wordSpacing, 0);
      expect(s.paragraph.inherit, false);
      expect(s.headings.map((h) => h.fontSize), [
        25.5,
        21.25,
        19.125,
        17,
        17,
        17,
      ]);
      for (final (i, h) in s.headings.indexed) {
        expect(h.letterSpacing, 0);
        expect(h.wordSpacing, 0);
        expect(h.height, 1.4);
        expect(h.fontWeight, i < 2 ? FontWeight.w700 : FontWeight.w600);
        expect(h.inherit, false);
      }
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      'SF tracking is interpolated by final point size only for the system font on $platform',
      (tester) async {
        double at(double size, {String? family}) => buildEditorStyle(
          brightness: Brightness.light,
          fontFamily: family,
          fontScale: size / 17,
        ).paragraph.letterSpacing!;
        for (final (size, tracking) in <(double, double)>[
          (12, 0),
          (13, -.08),
          (17, -.43),
          (17.5, -.435),
          (19, -.45),
          (19.5, -.45),
          (20, -.45),
          (21.25, -.335),
          (25.5, .185),
          (28, .38),
          (80, 0),
          (120, 0),
        ]) {
          expect(at(size), closeTo(tracking, .000001), reason: '$size pt');
        }
        expect(at(17, family: '.AppleSystemUIFont'), -.43);
        expect(at(52), platform == TargetPlatform.macOS ? .31 : .33);
        expect(at(53), platform == TargetPlatform.macOS ? .33 : .31);
        for (final family in ['MyCustomFont', 'SF Pro Text', 'Georgia']) {
          expect(at(17, family: family), 0);
          expect(
            buildEditorStyle(
              brightness: Brightness.light,
              fontFamily: family,
            ).paragraph.fontVariations,
            isNull,
          );
        }
        final s = buildEditorStyle(brightness: Brightness.light);
        expect(
          s.headings.map((h) => h.letterSpacing),
          orderedEquals(
            [
              .185,
              -.335,
              -.45,
              -.43,
              -.43,
              -.43,
            ].map((n) => closeTo(n, .000001)),
          ),
        );
        expect(s.paragraph.fontVariations!.single.axis, 'opsz');
        expect(s.paragraph.fontVariations!.single.value, 17);
        expect(s.headings[1].fontVariations!.single.value, 21.25);
        expect(s.codeBlock.letterSpacing, 0);
        expect(s.marks['code']!.letterSpacing, 0);
        final scaled = buildEditorStyle(
          brightness: Brightness.light,
          fontScale: 1.25 * 1.1,
        );
        // 17 * 1.25 * 1.1 = 23.375, between the 23 and 24 pt entries.
        expect(
          scaled.paragraph.letterSpacing,
          closeTo(-.10 + .17 * .375, .000001),
        );
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('non-Apple system fonts keep zero tracking on $platform', (
      tester,
    ) async {
      final s = buildEditorStyle(brightness: Brightness.light);
      expect(s.paragraph.letterSpacing, 0);
      expect(s.headings.map((h) => h.letterSpacing), everyElement(0));
    }, variant: TargetPlatformVariant({platform}));
  }
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'title is transparent and empty metadata uses faint roles in $brightness',
      (tester) async {
        await tester.pumpWidget(
          _app(
            MoodiaryEditor(
              initialTitle: 'Title',
              metaJson: jsonEncode({
                'dateText': 'Today',
                'subText': '',
                'moods': [],
                'tags': [],
              }),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.widget<TextField>(
          find.byKey(const ValueKey('editor-title')),
        );
        expect(title.decoration!.filled, false);
        expect(title.decoration!.border, InputBorder.none);
        expect(title.decoration!.fillColor, Colors.transparent);
        expect(title.style!.fontSize, 28);
        expect(title.style!.fontWeight, FontWeight.w700);
        expect(title.style!.inherit, false);
        expect(title.style!.letterSpacing, 0);
        expect(title.style!.fontVariations, isNull);
        final colors = MuiTheme.of(tester.element(find.byType(MoodiaryEditor)))
            .colors;
        final faint = Color.lerp(colors.surface, colors.onSurfaceVariant, .6);
        for (final label in [
          l10n.editor.meta.weather,
          l10n.editor.meta.place,
          l10n.editor.meta.category,
          l10n.editor.meta.tag,
        ]) {
          expect(tester.widget<Text>(find.text(label)).style!.color, faint);
        }
        for (final icon in [
          LucideIcons.cloud,
          LucideIcons.mapPin,
          LucideIcons.folder,
          LucideIcons.hash,
        ]) {
          expect(
            tester.widget<Icon>(find.byIcon(icon)).color,
            colors.outlineVariant,
          );
        }
      },
    );
  }
  testWidgets('recorded metadata uses onSurfaceVariant and the icon blend', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MoodiaryEditor(
          metaJson: jsonEncode({
            'dateText': 'Today',
            'subText': '',
            'moods': [],
            'tags': [],
            'weather': {'text': 'Sunny'},
            'position': 'Home',
            'category': 'Personal',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final colors = MuiTheme.of(tester.element(find.byType(MoodiaryEditor)))
        .colors;
    for (final label in ['Sunny', 'Home', 'Personal']) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        colors.onSurfaceVariant,
      );
    }
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.cloud)).color,
      Color.lerp(colors.surface, colors.onSurfaceVariant, .7),
    );
  });
  for (final heading in [false, true]) {
    testWidgets(
      'tracked ${heading ? 'H2' : 'body'} width matches plain Text metrics on Apple',
      (tester) async {
        final schema = ft.Schema.standard(),
            text = heading
                ? 'The quick brown fox'
                : 'The quick brown fox jumps over the lazy dog.';
        final node = schema.node(
          heading ? 'heading' : 'paragraph',
          attrs: heading ? {'level': 2} : null,
          content: [schema.node('text', text: text)],
        );
        final controller = ft.TiptapController(
          doc: schema.node('doc', content: [node]),
        );
        addTearDown(controller.dispose);
        final style = buildEditorStyle(brightness: Brightness.light),
            key = GlobalKey<ft.TiptapEditorState>();
        await tester.pumpWidget(
          _app(
            ft.TiptapEditor(
              key: key,
              controller: controller,
              style: style,
              readOnly: true,
            ),
          ),
        );
        await tester.pump();
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              inherit: false,
              fontFamily: '.AppleSystemUIFont',
              fontSize: heading ? 21.25 : 17,
              fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: heading ? -.335 : -.43,
              fontVariations: [FontVariation('opsz', heading ? 21.25 : 17)],
              wordSpacing: 0,
              height: heading ? 1.4 : 1.65,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(
          key.currentState!.geometry!.caretRect(text.length + 1).left,
          closeTo(
            16 +
                painter
                    .getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: text.length),
                    )
                    .last
                    .right,
            .01,
          ),
        );
        painter.dispose();
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
}
