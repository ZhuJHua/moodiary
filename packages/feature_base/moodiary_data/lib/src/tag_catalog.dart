import 'dart:async';

import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data_providers.dart';
import 'tag_repository.dart';

part 'tag_catalog.g.dart';

@riverpod
Future<({Map<String, Tag> byId, List<TagUsage> usage})> tagCatalog(
  Ref ref,
) async {
  final repo = ref.watch(tagRepositoryProvider);
  Timer? timer;
  void invalidate(Object _) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 200), ref.invalidateSelf);
  }

  final tags = repo.tagEvents.listen(invalidate);
  final diaries = ref
      .watch(diaryRepositoryProvider)
      .diaryEvents
      .listen(invalidate);
  ref.onDispose(() {
    timer?.cancel();
    tags.cancel();
    diaries.cancel();
  });
  return (
    byId: {
      for (final tag in await repo.getAllTags(includeDeleted: true))
        tag.id: tag,
    },
    usage: await repo.getTagUsage(),
  );
}

List<({String id, String name})> resolveTagNames(
  List<String> tagIds,
  Map<String, Tag> byId,
) {
  final seen = <String>{};
  return [
    for (final id in tagIds)
      if (byId[id] case Tag(:final name, deleted: false) when seen.add(name))
        (id: id, name: name),
  ];
}

Iterable<String> tagIdsWithName(
  List<String> tagIds,
  Map<String, Tag> byId,
  String name,
) => tagIds.where((id) {
  final tag = byId[id];
  return tag != null && !tag.deleted && tag.name == name;
});
