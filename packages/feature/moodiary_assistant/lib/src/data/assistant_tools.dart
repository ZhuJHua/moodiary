import 'package:moodiary_utils/moodiary_utils.dart';
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
  static const _maxDiaryHits = 8;

  static const _maxExcerptLength = 200;

  static const List<AssistantToolSpec> specs = [
    AssistantToolSpec(
      tool: AssistantTool.searchDiaries,
      description:
          '按关键词检索用户的本地日记，返回最相关的若干条日记摘要（含 id、日期、标题、正文片段）。'
          '当用户的问题涉及他们写过的日记、过往经历、情绪记录，或在修改 / 删除日记前需先定位目标时调用。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '空格分隔的检索关键词，例如 "旅行 海边"。'},
        },
        'required': ['query'],
      },
      run: _searchDiaries,
    ),
    AssistantToolSpec(
      tool: AssistantTool.createDiary,
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
      tool: AssistantTool.updateDiary,
      description:
          '按 id 修改一篇已有日记。只更新提供的字段（title / content / mood / categoryId），'
          '未提供的保持不变。调用前请先用 searchDiaries 拿到目标日记的 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '目标日记的 id（来自 searchDiaries）。',
          },
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
      tool: AssistantTool.deleteDiary,
      description:
          '按 id 把一篇日记移入回收站（软删除，可在回收站恢复）。'
          '调用前请先用 searchDiaries 确认目标日记的 id。',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '目标日记的 id（来自 searchDiaries）。',
          },
        },
        'required': ['id'],
      },
      run: _deleteDiary,
    ),
    AssistantToolSpec(
      tool: AssistantTool.listCategories,
      description:
          '列出用户的全部日记分类（返回每个分类的 id 与名称）。在按分类创建 / 归类日记，'
          '或修改 / 删除分类前调用以获取 id。',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listCategories,
    ),
    AssistantToolSpec(
      tool: AssistantTool.createCategory,
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
      tool: AssistantTool.updateCategory,
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
      tool: AssistantTool.deleteCategory,
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
  ];

  static AssistantToolSpec? byId(String id) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  static Future<String> _searchDiaries(Map<String, dynamic> input) async {
    final query = (input['query'] as String?)?.trim() ?? '';
    final keywords = query
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (keywords.isEmpty) return '没有提供检索关键词。';

    final diaries = await DiaryRepository.get().searchDiaries(
      cutTokens: keywords,
      cutForSearchTokens: keywords,
    );
    if (diaries.isEmpty) {
      return '没有找到与「${keywords.join(' ')}」相关的日记。';
    }

    final buffer = StringBuffer();
    for (final diary in diaries.take(_maxDiaryHits)) {
      final title = diary.title.trim().isEmpty ? '(无标题)' : diary.title.trim();
      buffer.writeln('id=${diary.id} 【${TimeUtil.isoDate(diary.time)}】$title');
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
    return '已创建日记「${title.isEmpty ? '(无标题)' : title}」（${TimeUtil.isoDate(diary.time)}），id=${diary.id}。';
  }

  static ({String content, String contentText, DiaryType type}) _toTiptap(
    String markdown,
  ) {
    final json = MarkdownToTiptap.convert(markdown);
    if (json != null && json.isNotEmpty) {
      return (
        content: json,
        contentText: TiptapContent.plainText(json),
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
    if (existing == null || existing.deleted) {
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
    }
    final mood = _parseMood(input['mood']);
    if (mood != null) updated = updated.copyWith(mood: mood);
    if (input.containsKey('categoryId')) {
      updated = updated.copyWith(
        categoryId: await _resolveCategoryId(input['categoryId']),
      );
    }
    updated = updated.copyWith(lastModified: DateTime.timestamp());

    await repo.updateADiary(newDiary: updated);
    final shown = updated.title.trim().isEmpty ? '(无标题)' : updated.title.trim();
    return '已更新日记「$shown」（id=$id）。';
  }

  static Future<String> _deleteDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return '删除失败：缺少日记 id。';

    final repo = DiaryRepository.get();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null || existing.deleted) {
      return '删除失败：未找到 id=$id 的日记。';
    }
    final ok = await repo.deleteADiary(existing.isarId);
    final title = existing.title.trim().isEmpty
        ? '(无标题)'
        : existing.title.trim();
    return ok ? '已将日记「$title」（id=$id）移入回收站。' : '删除失败，请稍后再试。';
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
    if (existing == null || existing.deleted) {
      return '修改失败：未找到 id=$id 的分类。';
    }
    final updated = existing.copyWith(
      categoryName: name,
      lastModified: DateTime.timestamp(),
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

  static Future<String?> _resolveCategoryId(Object? raw) async {
    final id = (raw as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final cat = await CategoryRepository.get().getCategoryById(id);
    return (cat == null || cat.deleted) ? null : id;
  }

  static double? _parseMood(Object? raw) =>
      raw is num ? raw.toDouble().clamp(0.0, 1.0).toDouble() : null;

}
