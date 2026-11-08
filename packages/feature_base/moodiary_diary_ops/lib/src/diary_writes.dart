/// Write side of the diary catalog: create, patch and delete, with the content
/// codec and the delete/index policies passed in by the caller.
///
/// The invariants live here so the assistant tools and the MCP server cannot
/// drift apart: a body change re-derives the media lists, every user edit bumps
/// `lastModified`, and a category id is validated before it is stored.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// How a caller hands a body in.
///
/// The assistant writes Markdown and lets the editor conversion keep the
/// formatting; MCP clients write plain text paragraphs. The stored
/// representation differs, so the choice is explicit rather than global.
enum DiaryContentFormat { markdown, plainText }

/// Recycle bin versus permanent removal (which also drops local media).
enum DiaryDeleteMode { recycle, permanent }

/// What made a write fail. Callers turn this into their own error surface.
enum DiaryOpsFailure {
  notFound,
  alreadyRecycled,
  emptyContent,
  invalidCategory,
  fieldRequired,
  noChanges,
  categoryCycle,
}

class DiaryOpsException implements Exception {
  const DiaryOpsException(this.failure, {this.id, this.categoryId});

  final DiaryOpsFailure failure;
  final String? id;
  final String? categoryId;

  @override
  String toString() => 'DiaryOpsException($failure)';
}

/// A partial edit. Every field carries its own "was it sent" flag because the
/// update tools read an absent field as "leave it alone" and an empty string as
/// "clear it".
class DiaryPatch {
  const DiaryPatch({
    this.title,
    this.content,
    this.mood,
    this.moodSet = false,
    this.categoryId,
    this.time,
    this.tags,
    this.show,
  });

  final String? title;
  final String? content;
  final DiaryMood? mood;

  /// Whether the caller sent `mood` at all; a sent null clears it.
  final bool moodSet;

  final String? categoryId;
  final DateTime? time;
  final List<String>? tags;
  final bool? show;

  bool get isEmpty =>
      title == null &&
      content == null &&
      !moodSet &&
      categoryId == null &&
      time == null &&
      tags == null &&
      show == null;
}

typedef _Converted = ({String content, String contentText, DiaryType type});

class DiaryWrites {
  DiaryWrites({required this.diaries, this.categories});

  final DiaryRepository diaries;

  /// Only needed when a call carries a category id; a delete or a category-less
  /// write works without it.
  final CategoryRepository? categories;

  /// Creates one diary and returns the stored row.
  ///
  /// [requireKnownCategory] is false for the assistant, which drops an unknown
  /// category id instead of failing the tool call.
  Future<Diary> create({
    required String title,
    required String content,
    DiaryContentFormat format = DiaryContentFormat.markdown,
    DiaryMood? mood,
    String? categoryId,
    DateTime? time,
    List<String> tags = const [],
    bool show = true,
    bool requireKnownCategory = true,
  }) async {
    if (content.trim().isEmpty) {
      throw const DiaryOpsException(DiaryOpsFailure.emptyContent);
    }
    final resolved = await _resolveCategory(
      categoryId,
      requireKnown: requireKnownCategory,
    );
    final converted = _convert(content, format);
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
    if (time != null || !show) {
      diary = diary.copyWith(time: time ?? diary.time, show: show);
    }
    await diaries.insertADiary(diary);
    return diary;
  }

  /// Applies a patch; only the fields present in [patch] change.
  ///
  /// [requireVisible] makes a recycled diary look missing, which is what the
  /// assistant shows the user; MCP clients can still edit a hidden diary.
  Future<Diary> update({
    required String id,
    required DiaryPatch patch,
    DiaryContentFormat format = DiaryContentFormat.markdown,
    bool requireKnownCategory = true,
    bool requireVisible = false,
    IndexMode index = IndexMode.inline,
  }) async {
    final existing = await diaries.getDiaryByBusinessId(id);
    if (existing == null || (requireVisible && !existing.show)) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }

    var next = existing;
    if (patch.title case final title?) {
      next = next.copyWith(title: title);
    }
    if (patch.content case final content?) {
      final converted = _convert(content, format);
      // A body change drops the media references the new document no longer
      // contains, which is exactly what withDerivedMedia recomputes.
      next = withDerivedMedia(
        next.copyWith(
          content: converted.content,
          contentText: converted.contentText,
          type: converted.type.value,
        ),
      );
    }
    if (patch.moodSet) {
      next = next.copyWith(mood: patch.mood);
    }
    if (patch.categoryId case final categoryId?) {
      next = next.copyWith(
        categoryId: await _resolveCategory(
          categoryId,
          requireKnown: requireKnownCategory,
        ),
      );
    }
    if (patch.time case final time?) {
      next = next.copyWith(time: time);
    }
    if (patch.tags case final tags?) {
      next = next.copyWith(tags: tags);
    }
    if (patch.show case final show?) {
      next = next.copyWith(show: show);
    }

    next = touched(next);
    await diaries.updateADiary(newDiary: next, index: index);
    return next;
  }

  /// Recycles or permanently deletes one diary.
  ///
  /// [reportAlreadyRecycled] lets the assistant answer "already in the recycle
  /// bin" for a hidden row; MCP treats the call as a plain recycle.
  Future<({DiaryDeleteOutcome outcome, Diary diary})> delete({
    required String id,
    DiaryDeleteMode mode = DiaryDeleteMode.recycle,
    bool reportAlreadyRecycled = false,
  }) async {
    final existing = await diaries.getDiaryByBusinessId(id);
    if (existing == null) {
      throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
    }
    if (mode == DiaryDeleteMode.permanent) {
      final removed = await diaries.deleteADiary(id);
      if (!removed) {
        throw DiaryOpsException(DiaryOpsFailure.notFound, id: id);
      }
      return (outcome: DiaryDeleteOutcome.deleted, diary: existing);
    }
    if (!existing.show && reportAlreadyRecycled) {
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
    final category = await categories?.getCategoryById(id);
    if (category != null) return id;
    if (requireKnown) {
      throw DiaryOpsException(DiaryOpsFailure.invalidCategory, categoryId: id);
    }
    return null;
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
    }
  }
}

enum DiaryDeleteOutcome { recycled, deleted, alreadyRecycled }
