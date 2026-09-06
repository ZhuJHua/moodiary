import 'package:moodiary_models/moodiary_models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 一篇 markdown 文件头部声明的元数据。键与 `MarkdownWriter._frontMatter` 逐一对应，
/// 全部可空 —— 用户手写的包多半只有正文。
class MarkdownEntryMeta {
  final String? id;
  final String? title;

  /// 绝对时刻（UTC）。无时区的字面量按本地时间解释。
  final DateTime? time;
  final DiaryMood? mood;
  final String? category;
  final DiaryWeather? weather;
  final MarkdownPosition? position;
  final List<String> tags;

  const MarkdownEntryMeta({
    this.id,
    this.title,
    this.time,
    this.mood,
    this.category,
    this.weather,
    this.position,
    this.tags = const [],
  });

  static const empty = MarkdownEntryMeta();
}

class MarkdownPosition {
  final double latitude;
  final double longitude;
  final String name;

  const MarkdownPosition({
    required this.latitude,
    required this.longitude,
    required this.name,
  });
}

class ParsedMarkdown {
  final MarkdownEntryMeta meta;

  /// 去掉 front matter 之后的正文。
  final String body;

  const ParsedMarkdown(this.meta, this.body);
}

/// Markdown 导入的文本层：front matter 解析与缺省推导，纯函数、不碰文件系统。
abstract final class MarkdownFrontMatter {
  static final RegExp _fence = RegExp(r'^(---|\.\.\.)[ \t]*$');
  static final RegExp _heading = RegExp(r'^#[ \t]+(.+?)[ \t]*#*[ \t]*$');
  static final RegExp _leadingDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static ParsedMarkdown parse(String source) {
    var text = source;
    if (text.startsWith('﻿')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n');

    final lines = text.split('\n');
    if (lines.isEmpty || lines.first.trimRight() != '---') {
      return ParsedMarkdown(MarkdownEntryMeta.empty, text);
    }
    var close = -1;
    for (var i = 1; i < lines.length; i++) {
      if (_fence.hasMatch(lines[i])) {
        close = i;
        break;
      }
    }
    if (close < 0) return ParsedMarkdown(MarkdownEntryMeta.empty, text);

    // 顶部一条分割线加一段普通文字也长这样：YAML 解不出映射就当没有 front matter。
    final Object? yaml;
    try {
      yaml = loadYaml(lines.sublist(1, close).join('\n'));
    } catch (_) {
      return ParsedMarkdown(MarkdownEntryMeta.empty, text);
    }
    if (yaml is! Map) return ParsedMarkdown(MarkdownEntryMeta.empty, text);

    final body = lines.sublist(close + 1).join('\n');
    return ParsedMarkdown(_meta(yaml), body);
  }

  static MarkdownEntryMeta _meta(Map raw) {
    final map = {for (final e in raw.entries) e.key.toString(): e.value};
    final id = _string(map['id']);
    return MarkdownEntryMeta(
      id: id != null && _uuid.hasMatch(id) ? id.toLowerCase() : null,
      title: _string(map['title']),
      time: switch (_string(map['time'])) {
        final s? => parseTime(s),
        null => null,
      },
      mood: switch (_string(map['mood'])) {
        final s? => DiaryMood.values.asNameMap()[s],
        null => null,
      },
      category: _string(map['category']),
      weather: _weather(map['weather']),
      position: _position(map['position']),
      tags: _strings(map['tags']),
    );
  }

  static String? _string(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _strings(Object? v) {
    if (v is List) {
      return [for (final item in v) ?_string(item)];
    }
    final single = _string(v);
    return single == null ? const [] : [single];
  }

  /// `[icon, temp, text]`（导出形态）或 `{icon, temp, text}`。没有图标码就不算天气。
  static DiaryWeather? _weather(Object? v) {
    String? icon, temp, text;
    if (v is List) {
      icon = v.isNotEmpty ? _string(v[0]) : null;
      temp = v.length > 1 ? _string(v[1]) : null;
      text = v.length > 2 ? _string(v[2]) : null;
    } else if (v is Map) {
      icon = _string(v['icon']);
      temp = _string(v['temp']);
      text = _string(v['text']);
    }
    if (icon == null) return null;
    return DiaryWeather(icon: icon, temp: temp, text: text ?? '');
  }

  /// `[lat, lng, name]`（导出形态）或 `{latitude, longitude, name}`。坐标非法就丢掉。
  static MarkdownPosition? _position(Object? v) {
    double? lat, lng;
    String? name;
    if (v is List) {
      lat = v.isNotEmpty ? _double(v[0]) : null;
      lng = v.length > 1 ? _double(v[1]) : null;
      name = v.length > 2 ? _string(v[2]) : null;
    } else if (v is Map) {
      lat = _double(v['latitude'] ?? v['lat']);
      lng = _double(v['longitude'] ?? v['lng'] ?? v['lon']);
      name = _string(v['name']);
    }
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return MarkdownPosition(latitude: lat, longitude: lng, name: name ?? '');
  }

  static double? _double(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };

  /// ISO 8601（含 `T` / 空格分隔、可带 Z 或偏移）与 `yyyy-MM-dd`。无时区按本地。
  static DateTime? parseTime(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    return parsed?.toUtc();
  }

  /// 正文开头的一级标题：取走作标题，剩余作正文。没有就原样返回。
  static (String? title, String body) splitLeadingTitle(String body) {
    final lines = body.split('\n');
    var i = 0;
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) return (null, body);
    final match = _heading.firstMatch(lines[i]);
    if (match == null) return (null, body);
    final title = _unescape(match.group(1)!).trim();
    if (title.isEmpty) return (null, body);
    var rest = lines.sublist(i + 1);
    while (rest.isNotEmpty && rest.first.trim().isEmpty) {
      rest = rest.sublist(1);
    }
    return (title, rest.join('\n'));
  }

  /// 文件名开头的 `YYYY-MM-DD`（导出默认模板 `{date}-{title}`），当天零点、本地时区。
  static DateTime? dateFromFileName(String fileName) {
    final m = _leadingDate.firstMatch(p.basename(fileName));
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final local = DateTime(y, mo, d);
    // 2 月 30 日之类会被 DateTime 静默进位，不算有效日期。
    if (local.month != mo || local.day != d) return null;
    return local.toUtc();
  }

  /// 文件名去扩展名、去开头日期与紧随的分隔符；剩下的作标题。
  static String titleFromFileName(String fileName) {
    var name = p.basenameWithoutExtension(fileName);
    name = name.replaceFirst(_leadingDate, '');
    name = name.replaceFirst(RegExp(r'^[\s_\-–—]+'), '');
    return name.trim();
  }

  static String _unescape(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);
}
