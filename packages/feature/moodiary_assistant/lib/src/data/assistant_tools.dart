import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';

typedef AssistantToolRun = Future<String> Function(Map<String, dynamic> input);

class AssistantToolSpec {
  final AssistantTool tool;
  final String description;
  final Map<String, dynamic> jsonSchema;
  final AssistantToolRun run;

  const AssistantToolSpec({
    required this.tool,
    required this.description,
    required this.jsonSchema,
    required this.run,
  });

  String get id => tool.id;
}

abstract final class AssistantToolRegistry {
  static const _defaultQueryLimit = 8;

  static const _maxQueryLimit = 20;

  static const _maxExcerptLength = 200;

  static const _maxFullContentLength = 4000;

  static const List<AssistantToolSpec> specs = [
    AssistantToolSpec(
      tool: .queryDiaries,
      description:
          '查询 / 浏览用户的本地日记，所有参数均为可选过滤条件：关键词、分类、起止日期、排序、条数。'
          '提供关键词时按相关度检索；留空则按时间 / 分类浏览。'
          '每条结果含 id、日期、心情与正文摘要。当问题涉及用户写过的日记、过往经历、情绪记录，'
          '或在修改 / 删除日记前需先定位目标时调用。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'keywords': {
            'type': 'string',
            'description': '空格分隔的检索关键词，例如 "旅行 海边"。留空则不按关键词、改为按下列条件浏览。',
          },
          'categoryId': {
            'type': 'string',
            'description': '仅返回该分类下的日记（分类 id 取自 listCategories）。可留空。',
          },
          'startDate': {
            'type': 'string',
            'description': '起始日期（含），格式 YYYY-MM-DD，按用户本地时区。可留空。',
          },
          'endDate': {
            'type': 'string',
            'description': '结束日期（含），格式 YYYY-MM-DD，按用户本地时区。可留空。',
          },
          'sort': {
            'type': 'string',
            'enum': ['newest', 'oldest', 'modified', 'relevance'],
            'description':
                '排序方式：newest 最新优先（默认）、oldest 最早优先、'
                'modified 最近修改优先、relevance 相关度（仅在提供关键词时有效）。',
          },
          'limit': {
            'type': 'integer',
            'description': '最多返回条数，默认 8，最大 20。',
            'minimum': 1,
            'maximum': 20,
          },
        },
      },
      run: _queryDiaries,
    ),
    AssistantToolSpec(
      tool: .getDiary,
      description:
          '按 id 读取单篇日记的完整内容（queryDiaries 只返回摘要）。'
          '当需要日记全文来总结、引用或回答细节时调用。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '目标日记的 id（来自 queryDiaries）。'},
        },
        'required': ['id'],
      },
      run: _getDiary,
    ),
    AssistantToolSpec(
      tool: .diaryOverview,
      description:
          '返回日记的总体概况：总篇数、各分类的篇数、以及最早 / 最新日记的日期跨度。'
          '当用户询问「一共写了多少篇」「哪个分类最多」「从什么时候开始记」等统计类问题时调用。',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _diaryOverview,
    ),
    AssistantToolSpec(
      tool: .createDiary,
      description:
          '为用户创建一条新的本地日记并保存。当用户明确要求「记录 / 写一篇 / 创建日记」'
          '或希望把某段内容存为日记时调用。正文支持 Markdown，可选填 categoryId（取自 listCategories）。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': '日记标题，可留空。'},
          'content': {'type': 'string', 'description': '日记正文，支持 Markdown 格式。'},
          'mood': {
            'type': 'number',
            'description': '心情指数，0.0（低落）到 1.0（愉悦）之间，可选，默认 0.5。',
            'minimum': 0,
            'maximum': 1,
          },
          'categoryId': {
            'type': 'string',
            'description': '归属分类 id（取自 listCategories），可留空。',
          },
        },
        'required': ['content'],
      },
      run: _createDiary,
    ),
    AssistantToolSpec(
      tool: .updateDiary,
      description:
          '按 id 修改一篇已有日记。只更新提供的字段（title / content / mood / categoryId），'
          '未提供的保持不变。调用前请先用 queryDiaries 拿到目标日记的 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '目标日记的 id（来自 queryDiaries）。'},
          'title': {'type': 'string', 'description': '新的标题，可选。'},
          'content': {'type': 'string', 'description': '新的正文（Markdown），可选。'},
          'mood': {
            'type': 'number',
            'description': '新的心情指数 0.0~1.0，可选。',
            'minimum': 0,
            'maximum': 1,
          },
          'categoryId': {'type': 'string', 'description': '新的归属分类 id，可选。'},
        },
        'required': ['id'],
      },
      run: _updateDiary,
    ),
    AssistantToolSpec(
      tool: .deleteDiary,
      description:
          '按 id 把一篇日记移入回收站（软删除，可在回收站恢复）。'
          '调用前请先用 queryDiaries 确认目标日记的 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '目标日记的 id（来自 queryDiaries）。'},
        },
        'required': ['id'],
      },
      run: _deleteDiary,
    ),
    AssistantToolSpec(
      tool: .listCategories,
      description:
          '列出用户的全部日记分类（返回每个分类的 id 与名称）。在按分类创建 / 归类日记，'
          '或修改 / 删除分类前调用以获取 id。',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listCategories,
    ),
    AssistantToolSpec(
      tool: .createCategory,
      description: '新建一个日记分类。当用户希望新增一个分类时调用。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '分类名称。'},
        },
        'required': ['name'],
      },
      run: _createCategory,
    ),
    AssistantToolSpec(
      tool: .updateCategory,
      description: '按 id 重命名一个分类。调用前请先用 listCategories 获取目标分类的 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '目标分类的 id（来自 listCategories）。',
          },
          'name': {'type': 'string', 'description': '新的分类名称。'},
        },
        'required': ['id', 'name'],
      },
      run: _updateCategory,
    ),
    AssistantToolSpec(
      tool: .deleteCategory,
      description:
          '按 id 删除一个分类（仅当该分类下没有任何日记时才会成功）。'
          '调用前请先用 listCategories 获取 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '目标分类的 id（来自 listCategories）。',
          },
        },
        'required': ['id'],
      },
      run: _deleteCategory,
    ),
    AssistantToolSpec(
      tool: .listMemories,
      description:
          '列出你已保存的关于用户的长期记忆（每条含 id、类别、内容）。'
          '在修改（updateMemory）或删除（forgetFact）某条记忆前，先用它获取目标 id。',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listMemories,
    ),
    AssistantToolSpec(
      tool: .rememberFact,
      description:
          '保存一条关于用户的长期事实（稳定的偏好、反复出现的主题或持续的目标），以便日后对话中记起。'
          '仅在确有长期价值时使用，不要保存一次性细节或用户要求勿记的内容。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'enum': ['preference', 'theme', 'goal', 'fact'],
            'description': '记忆类别：preference 偏好 | theme 主题 | goal 目标 | fact 事实。',
          },
          'text': {'type': 'string', 'description': '要记住的事实，一句话简明陈述。'},
        },
        'required': ['category', 'text'],
      },
      run: _rememberFact,
    ),
    AssistantToolSpec(
      tool: .updateMemory,
      description: '按 id 修改一条已保存的记忆内容。调用前请先用 listMemories 获取目标 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '目标记忆的 id（来自 listMemories）。'},
          'text': {'type': 'string', 'description': '新的记忆内容。'},
          'category': {
            'type': 'string',
            'enum': ['preference', 'theme', 'goal', 'fact'],
            'description': '可选，更新记忆类别。',
          },
        },
        'required': ['id', 'text'],
      },
      run: _updateMemory,
    ),
    AssistantToolSpec(
      tool: .forgetFact,
      description: '按 id 删除一条已保存的记忆。调用前请先用 listMemories 获取目标 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': '目标记忆的 id（来自 listMemories）。'},
        },
        'required': ['id'],
      },
      run: _forgetFact,
    ),
  ];

  static AssistantToolSpec? byId(String id) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  static Future<String> _queryDiaries(Map<String, dynamic> input) async {
    final rawKeywords = ((input['keywords'] as String?) ?? '').trim();
    final keywordsForDisplay = rawKeywords
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final categoryId = _trimToNull(input['categoryId']);
    final sortName = (input['sort'] as String?)?.trim();
    final limit = _parseLimit(input['limit']);
    // 起止日期按本地日历解释；结束日以次日零点作排他上界，从而包含整个结束日。
    final start = _parseDate(input['startDate']);
    final endExclusive = _parseDate(
      input['endDate'],
    )?.add(const Duration(days: 1));

    final repo = DiaryRepository.get();
    List<Diary> results;
    if (rawKeywords.isNotEmpty) {
      // 关键词必须走与建索引同一套 jieba 分词，否则中文按空格硬切、命中率骤降。
      final tokenized = await Tokenizer.tokenize(text: rawKeywords);
      results = await repo.searchDiaries(
        cutTokens: tokenized.cut,
        cutForSearchTokens: tokenized.cutForSearch,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _toSearchSort(sortName),
      );
    } else if (start != null || endExclusive != null) {
      final ranged = await repo.getDiariesByDateRange(
        start ?? .fromMillisecondsSinceEpoch(0),
        endExclusive ?? DateTime.now().add(const Duration(days: 1)),
      );
      results =
          ranged
              .where((d) => categoryId == null || d.categoryId == categoryId)
              .where((d) => _inRange(d.time, start, endExclusive))
              .toList()
            ..sort(_diaryComparator(sortName));
    } else {
      results = await repo.getDiaryByCategory(
        categoryId: categoryId,
        sort: _toDiarySort(sortName),
        limit: limit,
      );
    }

    if (results.isEmpty) {
      return _emptyQueryMessage(
        keywordsForDisplay,
        categoryId,
        start,
        endExclusive,
      );
    }
    return _formatDiaryList(results.take(limit));
  }

  static Future<String> _getDiary(Map<String, dynamic> input) async {
    final id = _trimToNull(input['id']);
    if (id == null) return '读取失败：缺少日记 id。';

    final diary = await DiaryRepository.get().getDiaryByBusinessId(id);
    // 排除回收站
    if (diary == null || !diary.show) {
      return '读取失败：未找到 id=$id 的日记。';
    }
    final title = diary.title.trim().isEmpty ? '(无标题)' : diary.title.trim();
    final buffer = StringBuffer()
      ..writeln('id=${diary.id}')
      ..writeln('日期=${TimeFormat.isoDate(diary.time)}')
      ..writeln('标题=$title')
      ..writeln('心情=${diary.mood.toStringAsFixed(2)}');
    if (diary.categoryId != null && diary.categoryId!.isNotEmpty) {
      buffer.writeln('分类id=${diary.categoryId}');
    }
    if (diary.tags.isNotEmpty) {
      buffer.writeln('标签=${diary.tags.join('、')}');
    }
    final text = diary.contentText.trim();
    buffer
      ..writeln('正文:')
      ..writeln(
        text.isEmpty
            ? '(空)'
            : (text.length > _maxFullContentLength
                  ? '${text.substring(0, _maxFullContentLength)}…'
                  : text),
      );
    return buffer.toString().trim();
  }

  static Future<String> _diaryOverview(Map<String, dynamic> input) async {
    final repo = DiaryRepository.get();
    final counts = await repo.diaryCountByCategory();
    if (counts.total == 0) return '目前还没有任何日记。';

    final cats = (await CategoryRepository.get().getAllCategories().run())
        .getOrElse((_) => const <Category>[]);
    final nameById = {for (final c in cats) c.id: c.categoryName};
    final newest = await repo.getDiaryByCategory(sort: .timeDesc, limit: 1);
    final oldest = await repo.getDiaryByCategory(sort: .timeAsc, limit: 1);

    final buffer = StringBuffer()..writeln('日记总数=${counts.total}');
    if (newest.isNotEmpty && oldest.isNotEmpty) {
      buffer.writeln(
        '时间跨度=${TimeFormat.isoDate(oldest.first.time)} ~ '
        '${TimeFormat.isoDate(newest.first.time)}',
      );
    }
    final categorized = counts.byCategory.values.fold<int>(0, (a, b) => a + b);
    final uncategorized = counts.total - categorized;
    buffer.writeln('分类统计:');
    if (counts.byCategory.isEmpty) {
      buffer.writeln('- （全部未分类）');
    } else {
      final entries = counts.byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in entries) {
        final name = nameById[e.key] ?? '(已删除分类)';
        buffer.writeln('- $name（id=${e.key}）：${e.value} 篇');
      }
    }
    if (uncategorized > 0) buffer.writeln('- 未分类：$uncategorized 篇');
    return buffer.toString().trim();
  }

  static Future<String> _createDiary(Map<String, dynamic> input) async {
    final title = (input['title'] as String?)?.trim() ?? '';
    final content = (input['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return '创建失败：日记正文不能为空。';

    final mood = _parseMood(input['mood']) ?? 0.5;
    final categoryId = await _resolveCategoryId(input['categoryId']);

    final converted = _toTiptap(content);
    final diary = Diary.create(
      categoryId: categoryId,
      title: title,
      content: converted.content,
      contentText: converted.contentText,
      mood: mood,
      weather: const [],
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      position: const [],
      type: converted.type,
      imageColor: null,
      aspect: null,
    );
    await DiaryRepository.get().insertADiary(diary);
    return '已创建日记「${title.isEmpty ? '(无标题)' : title}」（${TimeFormat.isoDate(diary.time)}），id=${diary.id}。';
  }

  static ({String content, String contentText, DiaryType type}) _toTiptap(
    String markdown,
  ) {
    final json = MarkdownToTiptap.convert(markdown);
    if (json != null && json.isNotEmpty) {
      return (
        content: json,
        contentText: TiptapContent.parse(json).plainText,
        type: DiaryType.tiptap,
      );
    }
    return (
      content: markdown,
      contentText: MarkdownConverter.convert(markdown),
      type: DiaryType.markdown,
    );
  }

  static Future<String> _updateDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return '修改失败：缺少日记 id。';

    final repo = DiaryRepository.get();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null || !existing.show) {
      return '修改失败：未找到 id=$id 的日记。';
    }

    var updated = existing;
    final title = input['title'] as String?;
    if (title != null) updated = updated.copyWith(title: title.trim());
    final content = input['content'] as String?;
    if (content != null) {
      final converted = _toTiptap(content);
      updated = updated.copyWith(
        content: converted.content,
        contentText: converted.contentText,
        type: converted.type.value,
      );
      // 内容变更必须重算媒体引用列表，否则媒体库出现幻影条目、废弃媒体永不回收。
      final media = DiaryContent.of(updated).media;
      updated = updated.copyWith(
        imageName: media.images,
        videoName: media.videos,
        audioName: media.audios,
      );
    }
    final mood = _parseMood(input['mood']);
    if (mood != null) updated = updated.copyWith(mood: mood);
    if (input.containsKey('categoryId')) {
      final rawCategory = (input['categoryId'] as String?)?.trim() ?? '';
      if (rawCategory.isEmpty) {
        updated = updated.copyWith(categoryId: null); // 显式清除归类
      } else {
        final resolved = await _resolveCategoryId(rawCategory);
        // 传了非空但无效的 id 时报错、保持原归类不变，避免「无效 id 静默清空分类」。
        if (resolved == null) {
          return '修改失败：未找到分类 id=$rawCategory（可先用 listCategories 确认）。';
        }
        updated = updated.copyWith(categoryId: resolved);
      }
    }
    updated = updated.copyWith(lastModified: .timestamp());

    await repo.updateADiary(newDiary: updated);
    final shown = updated.title.trim().isEmpty ? '(无标题)' : updated.title.trim();
    return '已更新日记「$shown」（id=$id）。';
  }

  static Future<String> _deleteDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return '删除失败：缺少日记 id。';

    final repo = DiaryRepository.get();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null) {
      return '删除失败：未找到 id=$id 的日记。';
    }
    final title = existing.title.trim().isEmpty
        ? '(无标题)'
        : existing.title.trim();
    if (!existing.show) {
      return '日记「$title」（id=$id）已在回收站中。';
    }
    // 软删=移入回收站(show=false)；勿用 deleteADiary(那是永久删除+删媒体)。
    await repo.updateADiary(
      newDiary: existing.copyWith(show: false, lastModified: .timestamp()),
    );
    return '已将日记「$title」（id=$id）移入回收站。';
  }

  static Future<String> _listCategories(Map<String, dynamic> input) async {
    final cats = (await CategoryRepository.get().getAllCategories().run())
        .getOrElse((_) => const <Category>[]);
    if (cats.isEmpty) return '当前还没有任何分类。';
    final buffer = StringBuffer();
    for (final c in cats) {
      buffer.writeln('id=${c.id} 名称=${c.categoryName}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _createCategory(Map<String, dynamic> input) async {
    final name = (input['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return '创建失败：分类名称不能为空。';
    final category = Category.create(categoryName: name);
    final ok = (await CategoryRepository.get().insertACategory(category).run())
        .isRight();
    return ok ? '已创建分类「$name」，id=${category.id}。' : '创建分类失败，请稍后再试。';
  }

  static Future<String> _updateCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    final name = (input['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) return '修改失败：缺少分类 id 或名称。';

    final repo = CategoryRepository.get();
    final existing = await repo.getCategoryById(id);
    if (existing == null) {
      return '修改失败：未找到 id=$id 的分类。';
    }
    final updated = existing.copyWith(
      categoryName: name,
      lastModified: .timestamp(),
    );
    final ok = (await repo.insertACategory(updated).run()).isRight();
    return ok ? '已将分类重命名为「$name」（id=$id）。' : '修改分类失败，请稍后再试。';
  }

  static Future<String> _deleteCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return '删除失败：缺少分类 id。';
    final ok = (await CategoryRepository.get().deleteACategory(id).run())
        .getOrElse((_) => false);
    return ok ? '已删除分类（id=$id）。' : '删除失败：分类不存在，或其下仍有日记（请先移除 / 改归类后再删）。';
  }

  static const _validMemoryCategories = {'preference', 'theme', 'goal', 'fact'};

  static Future<String> _listMemories(Map<String, dynamic> input) async {
    final memories = await MemoryRepository.get().getAll();
    if (memories.isEmpty) return '还没有保存任何关于用户的长期记忆。';
    final buffer = StringBuffer();
    for (final m in memories) {
      buffer.writeln('id=${m.id} 类别=${m.category} 内容=${m.text}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _rememberFact(Map<String, dynamic> input) async {
    final text = (input['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return '保存失败：记忆内容不能为空。';
    final rawCat = (input['category'] as String?)?.trim() ?? 'fact';
    final category = _validMemoryCategories.contains(rawCat) ? rawCat : 'fact';
    final entry = MemoryEntry.create(category: category, text: text);
    await MemoryRepository.get().put(entry);
    return '已记住（$category）：$text（id=${entry.id}）。';
  }

  static Future<String> _updateMemory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    final text = (input['text'] as String?)?.trim() ?? '';
    if (id.isEmpty || text.isEmpty) return '修改失败：缺少记忆 id 或内容。';
    final repo = MemoryRepository.get();
    final existing = await repo.get(id);
    if (existing == null) return '修改失败：未找到 id=$id 的记忆。';
    final rawCat = (input['category'] as String?)?.trim();
    final category = (rawCat != null && _validMemoryCategories.contains(rawCat))
        ? rawCat
        : existing.category;
    await repo.put(
      existing.copyWith(
        text: text,
        category: category,
        updatedAt: .timestamp(),
      ),
    );
    return '已更新记忆（id=$id）：$text。';
  }

  static Future<String> _forgetFact(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return '删除失败：缺少记忆 id。';
    final ok = await MemoryRepository.get().delete(id);
    return ok ? '已删除记忆（id=$id）。' : '删除失败：未找到 id=$id 的记忆。';
  }

  static Future<String?> _resolveCategoryId(Object? raw) async {
    final id = (raw as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final cat = await CategoryRepository.get().getCategoryById(id);
    return cat == null ? null : id;
  }

  static double? _parseMood(Object? raw) =>
      raw is num ? raw.toDouble().clamp(0.0, 1.0).toDouble() : null;

  static String? _trimToNull(Object? raw) {
    final s = (raw as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int _parseLimit(Object? raw) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
    if (n == null) return _defaultQueryLimit;
    return n.clamp(1, _maxQueryLimit);
  }

  /// 解析 `YYYY-MM-DD` 为本地日历日的零点。无法解析返回 null。
  static DateTime? _parseDate(Object? raw) {
    final s = (raw as String?)?.trim();
    if (s == null || s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// [start] 含、[endExclusive] 排他，按绝对时刻比较（`time` 为 UTC，本地边界仍按瞬时可比）。
  static bool _inRange(DateTime time, DateTime? start, DateTime? endExclusive) {
    if (start != null && time.isBefore(start)) return false;
    if (endExclusive != null && !time.isBefore(endExclusive)) return false;
    return true;
  }

  static SearchSort _toSearchSort(String? name) => switch (name) {
    'newest' => SearchSort.timeDesc,
    'oldest' => SearchSort.timeAsc,
    _ => SearchSort.relevance,
  };

  static DiarySort _toDiarySort(String? name) => switch (name) {
    'oldest' => DiarySort.timeAsc,
    'modified' => DiarySort.lastModifiedDesc,
    _ => DiarySort.timeDesc,
  };

  static int Function(Diary, Diary) _diaryComparator(String? name) =>
      switch (name) {
        'oldest' => (a, b) => a.time.compareTo(b.time),
        'modified' => (a, b) => b.lastModified.compareTo(a.lastModified),
        _ => (a, b) => b.time.compareTo(a.time),
      };

  static String _formatDiaryList(Iterable<Diary> diaries) {
    final buffer = StringBuffer();
    for (final diary in diaries) {
      final title = diary.title.trim().isEmpty ? '(无标题)' : diary.title.trim();
      final cat = diary.categoryId;
      final catPart = (cat != null && cat.isNotEmpty) ? ' 分类id=$cat' : '';
      buffer.writeln(
        'id=${diary.id} 【${TimeFormat.isoDate(diary.time)}】$title '
        '心情=${diary.mood.toStringAsFixed(2)}$catPart',
      );
      final text = diary.contentText.trim();
      if (text.isNotEmpty) {
        buffer.writeln(
          text.length > _maxExcerptLength
              ? '${text.substring(0, _maxExcerptLength)}…'
              : text,
        );
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static String _emptyQueryMessage(
    List<String> keywords,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  ) {
    final conds = <String>[
      if (keywords.isNotEmpty) '关键词「${keywords.join(' ')}」',
      if (categoryId != null) '分类 $categoryId',
      if (start != null) '起 ${TimeFormat.isoDate(start)}',
      if (endExclusive != null)
        '止 ${TimeFormat.isoDate(endExclusive.subtract(const Duration(days: 1)))}',
    ];
    return conds.isEmpty ? '还没有任何日记。' : '没有找到符合条件（${conds.join('，')}）的日记。';
  }
}
