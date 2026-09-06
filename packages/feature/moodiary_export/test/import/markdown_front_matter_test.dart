import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('MarkdownFrontMatter.parse', () {
    test('解出导出形态的全部键', () {
      const source = '''
---
id: "01912345-89ab-7cde-8f01-23456789abcd"
title: "今天：很好"
time: "2026-09-06T10:30:00.000"
mood: fulfilled
category: "生活"
weather: ["100", "26", "晴"]
position: ["30.25", "120.15", "西湖"]
tags: ["a", "b"]
---

正文第一行
''';
      final parsed = MarkdownFrontMatter.parse(source);
      final meta = parsed.meta;
      expect(meta.id, '01912345-89ab-7cde-8f01-23456789abcd');
      expect(meta.title, '今天：很好');
      expect(meta.time, DateTime(2026, 9, 6, 10, 30).toUtc());
      expect(meta.time!.isUtc, isTrue);
      expect(meta.mood, DiaryMood.fulfilled);
      expect(meta.category, '生活');
      expect(
        meta.weather,
        const DiaryWeather(icon: '100', temp: '26', text: '晴'),
      );
      expect(meta.position!.latitude, 30.25);
      expect(meta.position!.longitude, 120.15);
      expect(meta.position!.name, '西湖');
      expect(meta.tags, ['a', 'b']);
      expect(parsed.body.trim(), '正文第一行');
    });

    test('没有 front matter 时正文原样', () {
      final parsed = MarkdownFrontMatter.parse('# 标题\n\n正文');
      expect(parsed.meta.title, isNull);
      expect(parsed.body, '# 标题\n\n正文');
    });

    test('顶部分割线 + 普通文字不是 front matter', () {
      const source = '---\n第一段\n---\n第二段';
      final parsed = MarkdownFrontMatter.parse(source);
      expect(parsed.meta.title, isNull);
      expect(parsed.body, source);
    });

    test('YAML 非法时退为无 front matter', () {
      const source = '---\ntitle: [unclosed\n---\n正文';
      final parsed = MarkdownFrontMatter.parse(source);
      expect(parsed.meta.title, isNull);
      expect(parsed.body, source);
    });

    test('宽容形态：未知心情、空温度、非法坐标、非 uuid 的 id、标量 tags', () {
      const source = '''
---
id: 42
mood: ecstatic
weather: ["101", "", "多云"]
position: ["91", "120", "x"]
tags: solo
---
''';
      final meta = MarkdownFrontMatter.parse(source).meta;
      expect(meta.id, isNull);
      expect(meta.mood, isNull);
      expect(meta.weather, const DiaryWeather(icon: '101', text: '多云'));
      expect(meta.position, isNull);
      expect(meta.tags, ['solo']);
    });

    test('CRLF 与 BOM 都认', () {
      const source = '﻿---\r\ntitle: "x"\r\n---\r\n正文\r\n';
      final parsed = MarkdownFrontMatter.parse(source);
      expect(parsed.meta.title, 'x');
      expect(parsed.body, '正文\n');
    });
  });

  group('与 MarkdownWriter 往返', () {
    test('导出的 front matter 原样解回，时间跨时区仍是同一时刻', () {
      final time = DateTime(2026, 9, 6, 10, 30);
      final doc = TiptapToIr.convert(
        id: '01912345-89ab-7cde-8f01-23456789abcd',
        title: '标题: 带冒号',
        time: time,
        content: jsonEncode({
          'type': 'doc',
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': '正文'},
              ],
            },
          ],
        }),
        resolvePath: (kind, name) => '/data/$kind/$name',
        mood: DiaryMood.travel,
        weather: const DiaryWeather(icon: '100', text: '晴'),
        place: Place.create(name: '西湖', latitude: 30.25, longitude: 120.15),
        tags: const ['a', 'b'],
        categoryName: '旅行',
      );
      final md = MarkdownWriter.write(doc);
      expect(
        md,
        contains(RegExp(r'^time: .*([+-]\d\d:\d\d|Z)$', multiLine: true)),
      );

      final parsed = MarkdownFrontMatter.parse(md);
      final meta = parsed.meta;
      expect(meta.id, '01912345-89ab-7cde-8f01-23456789abcd');
      expect(meta.title, '标题: 带冒号');
      expect(meta.time, time.toUtc());
      expect(meta.mood, DiaryMood.travel);
      expect(meta.category, '旅行');
      expect(meta.weather, const DiaryWeather(icon: '100', text: '晴'));
      expect(meta.position!.name, '西湖');
      expect(meta.position!.latitude, 30.25);
      expect(meta.tags, ['a', 'b']);
      final (title, body) = MarkdownFrontMatter.splitLeadingTitle(parsed.body);
      expect(title, '标题: 带冒号');
      expect(body.trim(), '正文');
    });
  });

  group('parseTime', () {
    test('三种字面量与带时区', () {
      expect(
        MarkdownFrontMatter.parseTime('2026-09-06 10:30'),
        DateTime(2026, 9, 6, 10, 30).toUtc(),
      );
      expect(
        MarkdownFrontMatter.parseTime('2026-09-06'),
        DateTime(2026, 9, 6).toUtc(),
      );
      expect(
        MarkdownFrontMatter.parseTime('2026-09-06T02:30:00Z'),
        DateTime.utc(2026, 9, 6, 2, 30),
      );
      expect(MarkdownFrontMatter.parseTime('昨天'), isNull);
    });
  });

  group('缺省推导', () {
    test('正文首个一级标题作标题并从正文取走', () {
      final (title, body) = MarkdownFrontMatter.splitLeadingTitle(
        '\n# a\\_b #\n\n\n正文\n',
      );
      expect(title, 'a_b');
      expect(body, '正文\n');
    });

    test('不是一级标题开头就不动', () {
      final (title, body) = MarkdownFrontMatter.splitLeadingTitle('## 二级\n正文');
      expect(title, isNull);
      expect(body, '## 二级\n正文');
    });

    test('文件名开头的日期', () {
      expect(
        MarkdownFrontMatter.dateFromFileName('2026-09-06-标题.md'),
        DateTime(2026, 9, 6).toUtc(),
      );
      expect(MarkdownFrontMatter.dateFromFileName('2026-02-30-x.md'), isNull);
      expect(MarkdownFrontMatter.dateFromFileName('notes.md'), isNull);
    });

    test('文件名作标题时去掉日期与分隔符', () {
      expect(MarkdownFrontMatter.titleFromFileName('2026-09-06-标题.md'), '标题');
      expect(
        MarkdownFrontMatter.titleFromFileName('2026-09-06 标题 (2).md'),
        '标题 (2)',
      );
      expect(MarkdownFrontMatter.titleFromFileName('notes.md'), 'notes');
    });
  });
}
