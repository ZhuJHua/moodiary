import 'dart:convert';
import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'import_media_stage.dart';
import 'import_source.dart';
import 'markdown_front_matter.dart';

class MarkdownImportReport {
  final int diaries;
  final int categories;
  final int places;

  final int skipped;
  final int failed;

  final int missingMedia;

  final bool cancelled;

  const MarkdownImportReport({
    required this.diaries,
    required this.categories,
    required this.places,
    required this.skipped,
    required this.failed,
    required this.missingMedia,
    required this.cancelled,
  });
}

class MarkdownImporter {
  final DiaryRepository _diaries;
  final CategoryRepository _categories;
  final PlaceRepository _places;
  final ImportMediaStore _media;
  final DateTime Function() _now;

  MarkdownImporter({
    required this._diaries,
    required this._categories,
    required this._places,
    required this._media,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.timestamp;

  static const int _batchSize = 100;

  Future<MarkdownImportReport> run(
    MarkdownImportSource source, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final stage = ImportMediaStage(source.root, _media);
    final categoryIds = {
      for (final c in await _categories.getAllCategories())
        c.categoryName.trim(): c.id,
    };
    final places = List<Place>.of(await _places.getAllPlaces());
    final seenIds = <String>{};

    var imported = 0, skipped = 0, failed = 0;
    var newCategories = 0, newPlaces = 0;
    var cancelled = false;
    final batch = <Diary>[];

    Future<void> flush() async {
      if (batch.isEmpty) return;
      await _diaries.insertDiaries(List.of(batch));
      imported += batch.length;
      batch.clear();
    }

    final total = source.entries.length;
    for (var i = 0; i < total; i++) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      final entry = source.entries[i];
      try {
        final parsed = MarkdownFrontMatter.parse(
          utf8.decode(
            await File(entry.path).readAsBytes(),
            allowMalformed: true,
          ),
        );
        final meta = parsed.meta;

        final id = meta.id;
        if (id != null &&
            (!seenIds.add(id) ||
                await _diaries.getDiaryByBusinessId(id) != null)) {
          skipped++;
          continue;
        }

        var body = parsed.body;
        var title = meta.title;
        final (heading, rest) = MarkdownFrontMatter.splitLeadingTitle(body);
        if (heading != null && (title == null || heading == title.trim())) {
          title ??= heading;
          body = rest;
        }
        title ??= MarkdownFrontMatter.titleFromFileName(entry.name);

        body = await stage.rewrite(body, entry.path);
        final converted = _toTiptap(body);

        String? categoryId;
        final categoryName = meta.category?.trim();
        if (categoryName != null && categoryName.isNotEmpty) {
          categoryId = categoryIds[categoryName];
          if (categoryId == null) {
            final category = Category.create(categoryName: categoryName);
            await _categories.insertACategory(category);
            categoryIds[categoryName] = category.id;
            categoryId = category.id;
            newCategories++;
          }
        }

        String? placeId;
        if (meta.position case final position?) {
          final (resolved, created) = await _resolvePlace(position, places);
          placeId = resolved;
          if (created) newPlaces++;
        }

        final now = _now();
        final time =
            meta.time ??
            MarkdownFrontMatter.dateFromFileName(entry.name) ??
            _mtime(entry.path) ??
            now;

        batch.add(
          withDerivedMedia(
            Diary(
              id: id ?? uuidV7(),
              categoryId: categoryId,
              title: title,
              content: converted.content,
              contentText: converted.contentText,
              time: time,
              lastModified: now,
              show: true,
              mood: meta.mood ?? .neutral,
              weather: meta.weather,
              imageName: const [],
              audioName: const [],
              videoName: const [],
              tags: meta.tags,
              placeId: placeId,
              type: converted.type.value,
            ),
          ),
        );
        if (batch.length >= _batchSize) await flush();
      } catch (e, st) {
        failed++;
        logger.e('导入 ${entry.name} 失败', error: e, stackTrace: st);
      } finally {
        onProgress?.call(i + 1, total);
      }
    }
    await flush();

    return MarkdownImportReport(
      diaries: imported,
      categories: newCategories,
      places: newPlaces,
      skipped: skipped,
      failed: failed,
      missingMedia: stage.missing,
      cancelled: cancelled,
    );
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

  Future<(String id, bool created)> _resolvePlace(
    MarkdownPosition position,
    List<Place> known,
  ) async {
    if (position.name.isNotEmpty) {
      final byName = await _places.getPlaceByName(position.name);
      if (byName != null) return (byName.id, false);
    }
    final nearby = known.matchAt(position.latitude, position.longitude);
    if (nearby != null) return (nearby.id, false);

    final name = position.name.isNotEmpty
        ? position.name
        : Place.coordinateName(position.latitude, position.longitude);
    final place = Place.forName(
      name,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _places.insertAPlace(place);
    known.add(place);
    return (place.id, true);
  }

  static DateTime? _mtime(String path) {
    try {
      return File(path).lastModifiedSync().toUtc();
    } catch (_) {
      return null;
    }
  }
}
