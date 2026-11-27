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
  static const int previewRawLimit = 400;

  static final RegExp _reserved = RegExp('[\uFDD0-\uFDEF]');
  static final RegExp _lineBreaks = RegExp(r'\s*[\r\n]+\s*');
  // 保留名称两端的空白规则：U+0085 不算要剔除的空白，所以不用 String.trim()
  static final RegExp _edgeSpace = RegExp(r'^\s+|\s+$');

  static String open(MediaKind kind) =>
      String.fromCharCode(_firstOpen + kind.index);

  static String mark(MediaKind kind, String name) =>
      '${open(kind)}${sanitizeName(name)}$close';

  static String strip(String text) =>
      text.contains(_reserved) ? text.replaceAll(_reserved, '') : text;

  static String sanitizeName(String name) =>
      strip(name).replaceAll(_lineBreaks, ' ').replaceAll(_edgeSpace, '');

  static bool hasMarkup(String text) {
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (unit >= _close && unit <= _lastOpen) return true;
    }
    return false;
  }

  static String preview(String text, {int maxLines = 4, int maxRunes = 240}) {
    final raw = text.runes
        .take(previewRawLimit + 1)
        .takeWhile((rune) => rune != 0)
        .toList();
    final rawTruncated = raw.length > previewRawLimit;
    final lines = String.fromCharCodes(raw.take(previewRawLimit))
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .take(maxLines + 1);
    final excerpt = lines.join('\n').trim();
    final runes = excerpt.runes.take(maxRunes + 1).toList();
    final runeTruncated = runes.length > maxRunes;
    var end = runeTruncated ? maxRunes : runes.length;
    final lastClose = end == 0 ? -1 : runes.lastIndexOf(_close, end - 1);
    for (var index = lastClose + 1; index < end; index++) {
      final rune = runes[index];
      if (rune >= _firstOpen && rune <= _lastOpen) {
        end = index;
        break;
      }
    }
    if (end == 0) return '';
    if (!rawTruncated && !runeTruncated && end == runes.length) return excerpt;
    return '${String.fromCharCodes(runes.take(end)).trimRight()}…';
  }

  static String leadingExcerpt(String text, int length) {
    final runes = text.runes.toList();
    if (runes.length <= length) return text;
    var end = length;
    final lastOpen = runes.lastIndexWhere(
      (rune) => rune >= _firstOpen && rune <= _lastOpen,
      end - 1,
    );
    if (lastOpen > runes.lastIndexOf(_close, end - 1)) {
      final close = runes.indexOf(_close, end);
      end = close < 0 ? runes.length : close + 1;
    }
    if (end == runes.length) return text;
    return '${String.fromCharCodes(runes.take(end))}…';
  }

  static List<MarkupRun> parse(String text) {
    if (!hasMarkup(text)) return text.isEmpty ? const [] : [TextRun(text)];
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
