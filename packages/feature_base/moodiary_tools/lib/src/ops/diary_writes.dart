library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../tools/diary_payloads.dart';
import '../tools/diary_time.dart';

enum DiaryContentFormat { markdown, plainText, document }

enum DiaryOpsFailure {
  notFound,
  emptyContent,
  invalidCategory,
  fieldRequired,
  noChanges,

  invalidDocument,

  foreignMedia,
  conflictingBodyEdits,
  unsupportedBodyAddition,
  missingMedia,
  unknownMediaRemoval,
  mediaRemovalRequiresContent,
  rewriteTooLong,
}

class DiaryOpsException implements Exception {
  const DiaryOpsException(
    this.failure, {
    this.id,
    this.categoryId,
    this.maxRewriteChars,
    this.mediaNames = const [],
  });

  final DiaryOpsFailure failure;
  final String? id;
  final String? categoryId;
  final int? maxRewriteChars;
  final List<String> mediaNames;

  @override
  String toString() => 'DiaryOpsException($failure)';
}

/// A partial diary edit; an absent field stays unchanged.
class DiaryPatch {
  const DiaryPatch({
    this.title,
    this.content,
    this.append,
    this.prepend,
    this.removeMedia = const [],
    this.mood,
    this.moodSet = false,
    this.categoryId,
    this.time,
    this.timeInput,
    this.maxRewriteChars,
    this.tags,
  });

  final String? title;
  final String? content;
  final String? append;
  final String? prepend;
  final List<String> removeMedia;
  final DiaryMood? mood;

  /// Whether the caller sent `mood` at all; a sent null clears it.
  final bool moodSet;

  final String? categoryId;
  final DateTime? time;
  final String? timeInput;
  final int? maxRewriteChars;
  final List<String>? tags;

  bool get isEmpty =>
      title == null &&
      content == null &&
      append == null &&
      prepend == null &&
      removeMedia.isEmpty &&
      !moodSet &&
      categoryId == null &&
      time == null &&
      timeInput == null &&
      tags == null;
}

typedef _Converted = ({String content, String contentText, DiaryType type});

class DiaryWrites {
  DiaryWrites({required this.diaries, required this.categories});

  final DiaryRepository diaries;

  final CategoryRepository categories;

  /// Unknown categories are dropped unless [requireKnownCategory] is set.
  /// [enforceOwnMedia] rejects media references because a new diary owns none.
  Future<Diary> create({
    required String title,
    required String content,
    DiaryContentFormat format = DiaryContentFormat.markdown,
    DiaryMood? mood,
    String? categoryId,
    DateTime? time,
    List<String> tags = const [],
    bool requireKnownCategory = true,
    bool enforceOwnMedia = false,
  }) async {
    if (content.trim().isEmpty) {
      throw const DiaryOpsException(DiaryOpsFailure.emptyContent);
    }
    final resolved = await _resolveCategory(
      categoryId,
      requireKnown: requireKnownCategory,
    );
    final converted = _convert(content, format);
    if (enforceOwnMedia) {
      _rejectForeignMedia(null, converted.content, const {});
    }
    var diary = Diary.create(
      categoryId: resolved,
      title: title,
      content: converted.content,
      contentText: converted.contentText,
      mood: mood,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: tags,
      type: converted.type,
      aspect: null,
    );
    if (time != null) diary = diary.copyWith(time: time);
    // The body may carry media from the start; the repository stores the four
    // lists rather than re-deriving them, so they are derived here.
    diary = withDerivedMedia(diary);
    await diaries.insertADiary(diary);
    return diary;
  }

  /// [enforceOwnMedia] allows existing media plus [extraAllowedMedia].
  Future<Diary> update({
    required String id,
    required DiaryPatch patch,
    DiaryContentFormat format = DiaryContentFormat.markdown,
    IndexMode index = IndexMode.inline,
    bool enforceOwnMedia = false,
    Set<String> extraAllowedMedia = const {},
  }) async {
    final existing = await diaries.getDiaryByBusinessId(id);
    if (existing == null || !existing.show) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    if (patch.content != null && patch.maxRewriteChars != null) {
      if (readBody(existing, patch.maxRewriteChars!, 'markdown').truncated) {
        throw DiaryOpsException(
          DiaryOpsFailure.rewriteTooLong,
          id: id,
          maxRewriteChars: patch.maxRewriteChars,
        );
      }
    }
    if (patch.content != null &&
        (patch.append != null || patch.prepend != null)) {
      throw DiaryOpsException(DiaryOpsFailure.conflictingBodyEdits, id: id);
    }
    final ownedMedia = {
      ...existing.imageName,
      ...existing.audioName,
      ...existing.videoName,
      ...existing.fileName,
    };
    final unknown = patch.removeMedia.toSet().difference(ownedMedia);
    if (unknown.isNotEmpty) {
      throw DiaryOpsException(
        DiaryOpsFailure.unknownMediaRemoval,
        id: id,
        mediaNames: unknown.toList(),
      );
    }
    if (patch.removeMedia.isNotEmpty && patch.content == null) {
      throw DiaryOpsException(
        DiaryOpsFailure.mediaRemovalRequiresContent,
        id: id,
      );
    }

    var next = existing;
    if (patch.title case final title?) {
      next = next.copyWith(title: title);
    }
    if (patch.content case final content?) {
      final converted = _convert(content, format);
      if (enforceOwnMedia) {
        _rejectForeignMedia(existing, converted.content, extraAllowedMedia);
      }
      final missing = ownedMedia
          .difference(_mediaRefs(converted.content))
          .difference(patch.removeMedia.toSet());
      if (missing.isNotEmpty) {
        throw DiaryOpsException(
          DiaryOpsFailure.missingMedia,
          id: id,
          mediaNames: missing.toList(),
        );
      }
      next = withDerivedMedia(
        next.copyWith(
          content: converted.content,
          contentText: converted.contentText,
          type: converted.type.value,
        ),
      );
    }
    if (patch.append != null || patch.prepend != null) {
      final converted = _addBlocks(existing, patch);
      if (enforceOwnMedia) {
        final document = converted.type == DiaryType.markdown
            ? _convert(converted.content, DiaryContentFormat.markdown).content
            : converted.content;
        _rejectForeignMedia(existing, document, extraAllowedMedia);
      }
      next = withDerivedMedia(
        next.copyWith(
          content: converted.content,
          contentText: converted.contentText,
        ),
      );
    }
    if (patch.moodSet) {
      next = next.copyWith(mood: patch.mood);
    }
    if (patch.categoryId case final categoryId?) {
      next = next.copyWith(
        categoryId: await _resolveCategory(categoryId, requireKnown: true),
      );
    }
    final time = patch.timeInput == null
        ? patch.time
        : resolveDiaryTime(
            patch.timeInput,
            reference: existing.time,
            subject: 'update_diary',
          );
    if (time != null) {
      next = next.copyWith(time: time);
    }
    if (patch.tags case final tags?) {
      next = next.copyWith(tags: tags);
    }

    next = touched(next);
    await diaries.updateADiary(newDiary: next, index: index);
    return next;
  }

  _Converted _addBlocks(Diary existing, DiaryPatch patch) {
    switch (DiaryType.fromValue(existing.type)) {
      case DiaryType.richText:
        throw DiaryOpsException(
          DiaryOpsFailure.unsupportedBodyAddition,
          id: existing.id,
        );
      case DiaryType.markdown:
        final content = [
          ?patch.prepend,
          existing.content,
          ?patch.append,
        ].join('\n\n');
        return (
          content: content,
          contentText: DiaryContent.of(existing.copyWith(content: content))
              .plainText,
          type: DiaryType.markdown,
        );
      case DiaryType.tiptap:
        final parsed = TiptapContent.parse(existing.content);
        if (!parsed.isDoc) {
          throw DiaryOpsException(
            DiaryOpsFailure.invalidDocument,
            id: existing.id,
          );
        }
        List<dynamic> blocks(String? markdown) {
          if (markdown == null) return const [];
          final converted = _convert(markdown, DiaryContentFormat.markdown);
          if (converted.type != DiaryType.tiptap) {
            throw DiaryOpsException(
              DiaryOpsFailure.invalidDocument,
              id: existing.id,
            );
          }
          return TiptapContent.parse(converted.content).document!['content']
              as List;
        }
        final document = parsed.document!;
        final content = TiptapContent.fromDocument({
          ...document,
          'content': [
            ...blocks(patch.prepend),
            ...?document['content'] as List?,
            ...blocks(patch.append),
          ],
        }).normalized;
        return (
          content: content,
          contentText: TiptapContent.parse(content).plainText,
          type: DiaryType.tiptap,
        );
    }
  }

  Future<({DiaryDeleteOutcome outcome, Diary diary})> delete({
    required String id,
  }) async {
    final existing = await diaries.getDiaryByBusinessId(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    if (!existing.show) {
      return (outcome: DiaryDeleteOutcome.alreadyRecycled, diary: existing);
    }
    await diaries.setVisibility(existing, show: false);
    return (outcome: DiaryDeleteOutcome.recycled, diary: existing);
  }

  Future<String?> _resolveCategory(
    String? raw, {
    required bool requireKnown,
  }) async {
    final id = raw?.trim();
    if (id == null || id.isEmpty) return null;
    final category = await categories.getCategoryById(id);
    if (category != null) return id;
    if (requireKnown) {
      throw DiaryOpsException(DiaryOpsFailure.invalidCategory, categoryId: id);
    }
    return null;
  }

  void _rejectForeignMedia(
    Diary? existing,
    String content,
    Set<String> extraAllowedMedia,
  ) {
    final allowed = {
      ...?existing?.imageName,
      ...?existing?.audioName,
      ...?existing?.videoName,
      ...?existing?.fileName,
      ...extraAllowedMedia,
    };
    if (_mediaRefs(content).any((name) => !allowed.contains(name))) {
      throw DiaryOpsException(DiaryOpsFailure.foreignMedia, id: existing?.id);
    }
  }

  /// Every local media `src` [content] references, paths included, so a
  /// traversal `src` cannot slip past the ownership check.
  static Set<String> _mediaRefs(String content) {
    final document = TiptapContent.parse(content).document;
    final refs = <String>{};
    void walk(Object? node) {
      if (node is! Map) return;
      final type = node['type'];
      if (const {'image', 'audio', 'video', 'attachment'}.contains(type)) {
        final attrs = node['attrs'];
        final src = attrs is Map ? attrs['src'] : null;
        if (type != 'image' ||
            src is! String ||
            !(isNetworkMedia(src) || src.startsWith('data:image/'))) {
          refs.add(src is String ? src : '');
        }
      }
      final children = node['content'];
      if (children is List) children.forEach(walk);
    }

    walk(document);
    return refs;
  }

  _Converted _convert(String text, DiaryContentFormat format) {
    switch (format) {
      case DiaryContentFormat.markdown:
        final json = MarkdownToTiptap.convert(text);
        if (json != null && json.isNotEmpty) {
          return (
            content: json,
            contentText: TiptapContent.parse(json).plainText,
            type: DiaryType.tiptap,
          );
        }
        return (
          content: text,
          contentText: MarkdownConverter.convert(text),
          type: DiaryType.markdown,
        );
      case DiaryContentFormat.plainText:
        final wrapped = TiptapContent.wrapPlainText(text);
        return (
          content: wrapped,
          contentText: TiptapContent.parse(wrapped).plainText,
          type: DiaryType.tiptap,
        );
      case DiaryContentFormat.document:
        // A document body comes from a JSON aware client, so a malformed shape
        // is the caller's mistake, not an empty diary; normalize it the same
        // way the repository does so the stored row is canonical.
        final parsed = TiptapContent.parse(text);
        if (!parsed.isDoc) {
          throw const DiaryOpsException(DiaryOpsFailure.invalidDocument);
        }
        final normalized = parsed.normalized;
        return (
          content: normalized,
          contentText: TiptapContent.parse(normalized).plainText,
          type: DiaryType.tiptap,
        );
    }
  }
}

enum DiaryDeleteOutcome { recycled, alreadyRecycled }
