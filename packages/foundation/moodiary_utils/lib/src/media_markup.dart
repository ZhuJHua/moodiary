enum MediaKind { image, video, audio, attachment }

sealed class MarkupRun {
  final String text;

  const MarkupRun(this.text);
}

final class TextRun extends MarkupRun {
  const TextRun(super.text);
}

final class MediaRun extends MarkupRun {
  // null 是这个版本还不认识的类型
  final MediaKind? kind;

  const MediaRun(this.kind, super.text);
}

// 名称写成「U+FDD1 起按 MediaKind 排的开始符 + 名称 + U+FDD0」；U+FDD0–FDEF 是非字符，用户文字里的一律剔掉
abstract final class MediaMarkup {
  static const int _close = 0xFDD0;
  static const int _firstOpen = 0xFDD1;
  static const int _lastOpen = 0xFDEF;

  static const String close = '\uFDD0';

  static final RegExp _reserved = RegExp('[\uFDD0-\uFDEF]');
  static final RegExp _lineBreaks = RegExp(r'\s*[\r\n]+\s*');
  // 不用 String.trim()：它比 JS 的 trim 多剔 U+0085，两端纯文本会对不上
  static final RegExp _edgeSpace = RegExp(r'^\s+|\s+$');

  static String open(MediaKind kind) =>
      String.fromCharCode(_firstOpen + kind.index);

  static String mark(MediaKind kind, String name) =>
      '${open(kind)}${sanitizeName(name)}$close';

  static String strip(String text) =>
      text.contains(_reserved) ? text.replaceAll(_reserved, '') : text;

  static String sanitizeName(String name) =>
      strip(name).replaceAll(_lineBreaks, ' ').replaceAll(_edgeSpace, '');

  static List<MarkupRun> parse(String text) {
    final runs = <MarkupRun>[];
    final buf = StringBuffer();
    MediaKind? kind;
    var inMedia = false;
    void flush() {
      if (inMedia) {
        runs.add(MediaRun(kind, buf.toString()));
      } else if (buf.isNotEmpty) {
        runs.add(TextRun(buf.toString()));
      }
      buf.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit == _close) {
        if (inMedia) {
          flush();
          inMedia = false;
        }
      } else if (unit >= _firstOpen && unit <= _lastOpen) {
        flush();
        inMedia = true;
        final index = unit - _firstOpen;
        kind = index < MediaKind.values.length ? MediaKind.values[index] : null;
      } else {
        buf.writeCharCode(unit);
      }
    }
    flush();
    return runs;
  }

  static String body(String text) {
    if (!text.contains(_reserved)) return text;
    return parse(text).whereType<TextRun>().map((r) => r.text).join();
  }

  static String forModel(String text) {
    if (!text.contains(_reserved)) return text;
    return parse(text)
        .map(
          (r) => switch (r) {
            TextRun(:final text) => text,
            MediaRun(:final kind, :final text) =>
              '[${kind?.name ?? 'media'}: $text]',
          },
        )
        .join();
  }
}
