import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'db/database.dart';
import 'db/db_codec.dart';

typedef TagUsage = ({String name, int count, DateTime? lastUsed});

final class TagEvent {
  const TagEvent({this.fromSync = false});
  final bool fromSync;
}

class TagRepository {
  TagRepository(this._db);

  final MoodiaryDatabase _db;
  final _events = StreamController<TagEvent>.broadcast();
  Stream<TagEvent> get tagEvents => _events.stream;

  Future<void> dispose() => _events.close();

  static Tag _tag(TagRow row) => Tag(
    id: row.id,
    name: row.name,
    deleted: row.deleted != 0,
    lastModified: dbToTime(row.lastModified),
  );

  Future<List<Tag>> getAllTags({bool includeDeleted = false}) async {
    final query = _db.select(_db.tags)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    if (!includeDeleted) query.where((t) => t.deleted.equals(0));
    return (await query.get()).map(_tag).toList();
  }

  Future<Tag?> getTagById(String id) async {
    final row = await (_db.select(
      _db.tags,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _tag(row);
  }

  Future<Map<String, Tag>> getTagsByIds(Iterable<String> ids) async {
    final keys = ids.toSet().toList();
    final result = <String, Tag>{};
    for (var start = 0; start < keys.length; start += 500) {
      final chunk = keys.sublist(start, min(keys.length, start + 500));
      final rows = await (_db.select(
        _db.tags,
      )..where((t) => t.id.isIn(chunk))).get();
      for (final row in rows) {
        result[row.id] = _tag(row);
      }
    }
    return result;
  }

  Future<List<TagUsage>> getTagUsage() async {
    final rows = await _db.customSelect('''
SELECT t.name, count(DISTINCT d.id) AS uses, max(d.time) AS last_used
FROM tags t LEFT JOIN diary_tags dt ON dt.tag_id = t.id
LEFT JOIN diaries d ON d.id = dt.diary_id AND d.show = 1
WHERE t.deleted = 0 GROUP BY t.name ORDER BY uses DESC, last_used DESC, t.name
''').get();
    return [
      for (final row in rows)
        (
          name: row.read<String>('name'),
          count: row.read<int>('uses'),
          lastUsed: dbToTimeOrNull(row.readNullable<int>('last_used')),
        ),
    ];
  }

  Future<List<String>> ensureTags(List<String> names) =>
      _resolve(names, legacy: false, fromSync: false);

  Future<List<String>> adoptLegacyTags(
    List<String> names, {
    bool fromSync = true,
    bool restoring = false,
  }) => _resolve(names, legacy: true, fromSync: fromSync, restoring: restoring);

  Future<List<String>> _resolve(
    List<String> names, {
    required bool legacy,
    required bool fromSync,
    bool restoring = false,
  }) async {
    var changed = false;
    final ids = await _db.transaction(() async {
      final result = <String>[];
      for (final name in names.map(Tag.normalize).nonNulls.toSet()) {
        final query = _db.select(_db.tags);
        if (legacy) {
          query.where((t) => t.id.equals(Tag.legacyId(name)));
        } else {
          query.where((t) => t.name.equals(name) & t.deleted.equals(0));
          query.orderBy([(t) => OrderingTerm.asc(t.id)]);
        }
        query.limit(1);
        final row = await query.getSingleOrNull();
        if (row != null && !(restoring && row.deleted != 0)) {
          result.add(row.id);
          continue;
        }
        final tag = legacy ? Tag.legacy(name) : Tag.create(name);
        final updated = legacy && restoring
            ? tag.copyWith(lastModified: DateTime.timestamp())
            : tag;
        await _write(updated);
        changed = true;
        result.add(updated.id);
      }
      return result;
    });
    if (changed) _events.add(TagEvent(fromSync: fromSync));
    return ids;
  }

  Future<int> renameTag(String name, String newName) async {
    final normalized = Tag.normalize(newName);
    if (normalized == null) return 0;
    return _updateGroup(
      name,
      TagsCompanion(
        name: Value(normalized),
        lastModified: Value(dbTime(DateTime.timestamp())),
      ),
    );
  }

  Future<int> deleteTag(String name) => _updateGroup(
    name,
    TagsCompanion(
      deleted: const Value(1),
      lastModified: Value(dbTime(DateTime.timestamp())),
    ),
  );

  Future<int> _updateGroup(String name, TagsCompanion changes) async {
    final count = await (_db.update(
      _db.tags,
    )..where((t) => t.name.equals(name) & t.deleted.equals(0))).write(changes);
    if (count > 0) _events.add(const TagEvent());
    return count;
  }

  Future<void> _write(Tag tag) => _db
      .into(_db.tags)
      .insertOnConflictUpdate(
        TagsCompanion.insert(
          id: tag.id,
          name: tag.name,
          deleted: Value(tag.deleted ? 1 : 0),
          lastModified: dbTime(tag.lastModified),
        ),
      );

  Future<void> insertATag(Tag tag, {bool fromSync = false}) async {
    await _write(tag);
    _events.add(TagEvent(fromSync: fromSync));
  }
}
