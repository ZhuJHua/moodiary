import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_content/moodiary_content.dart';

void main() {
  test('hasMarkup detects every reserved code unit and only those units', () {
    expect(MediaMarkup.hasMarkup(''), isFalse);
    expect(MediaMarkup.hasMarkup('中文😀\uFDCF\uFDF0'), isFalse);
    for (var unit = 0xFDD0; unit <= 0xFDEF; unit++) {
      expect(MediaMarkup.hasMarkup('😀${String.fromCharCode(unit)}'), isTrue);
    }
  });

  test('parse returns plain text as one run and empty text as no runs', () {
    const plain = '中文😀\r\nSecond line';
    expect(MediaMarkup.parse(''), isEmpty);
    expect(MediaMarkup.parse(plain).single, isA<TextRun>());
    expect(MediaMarkup.parse(plain).single.text, same(plain));
  });

  test(
    'preview preserves a line for layout overflow and trims Unicode space',
    () {
      const text =
          '\u3000first\u00A0\r\n\u2003\r\n  second \nthird\n'
          'fourth\nfifth\nsixth';
      expect(
        MediaMarkup.preview(text),
        'first\n  second\nthird\nfourth\nfifth',
      );
      expect(MediaMarkup.preview(text, maxLines: 1), 'first\n  second');
      expect(MediaMarkup.preview('\u3000\n\u00A0'), isEmpty);
    },
  );

  test('preview bounds code points before trimming and preserves emoji', () {
    expect(MediaMarkup.preview('a${'😀' * 239}b'), 'a${'😀' * 239}…');
    expect(MediaMarkup.preview('a😀b', maxRunes: 2), 'a😀…');
    final exact = '😀${' ' * 399}';
    expect(MediaMarkup.preview(exact), '😀');
    expect(MediaMarkup.preview('${exact}b'), '😀…');
    expect(MediaMarkup.preview(' ' * 401), isEmpty);
    expect(MediaMarkup.preview('${'\n' * 400}tail'), isEmpty);
  });

  test('preview stops at a NUL like SQLite text substr', () {
    expect(MediaMarkup.preview('before\u0000after'), 'before');
  });

  test('preview preserves complete empty and unknown media tokens', () {
    const tokens = '\uFDD1\uFDD0\uFDEF😀\uFDD0';
    expect(MediaMarkup.preview(tokens), tokens);
    expect(MediaMarkup.preview('${tokens}b', maxRunes: 5), '$tokens…');
    final runs = MediaMarkup.parse(tokens).cast<MediaRun>();
    expect((runs[0].kind, runs[0].text), (MediaKind.image, ''));
    expect((runs[1].kind, runs[1].text), (null, '😀'));
  });

  test('preview drops incomplete tokens at each boundary', () {
    final complete = MediaMarkup.mark(.image, 'kept');
    const partial = '\uFDEE名字😀\uFDD0';
    expect(
      MediaMarkup.preview('$complete${'a' * 231}$partial'),
      '$complete${'a' * 231}…',
    );
    expect(MediaMarkup.preview('${' ' * 395}ok$partial', maxRunes: 400), 'ok…');
    expect(MediaMarkup.preview('ok\uFDD1orphan'), 'ok…');
  });
}
