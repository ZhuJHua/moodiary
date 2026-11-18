import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late TagRepository repo;

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    repo = TagRepository(db);
  });
  tearDown(() => db.close());

  test('ensure normalizes and reuses the smallest active id', () async {
    for (final id in ['z', 'a', '0']) {
      await repo.insertATag(
        Tag.legacy('two words').copyWith(id: id, deleted: id == '0'),
      );
    }
    final event = repo.tagEvents.first;
    final ids = await repo.ensureTags([
      ' # two\twords ',
      '#',
      ' #new ',
      'two words',
      'new',
    ]);
    expect(ids, hasLength(2));
    expect(ids.first, 'a');
    expect(ids.last, isNot(Tag.legacyId('new')));
    final created = await event as TagUpserted;
    expect(created.tag.id, ids.last);
    expect(created.fromSync, isFalse);
    expect(await repo.ensureTags(['new', 'two words']), ids.reversed);
  });

  test('chip edits match all active ids with the input name', () {
    final legacy = Tag.legacy('two words');
    final created = Tag.create('two words');
    final deleted = created.copyWith(id: 'deleted', deleted: true);
    final other = Tag.create('other');
    final byId = {
      for (final tag in [legacy, created, deleted, other]) tag.id: tag,
    };
    final ids = ['missing', created.id, deleted.id, legacy.id, other.id];
    final matches = tagIdsWithName(ids, byId, Tag.normalize(' #two  words ')!);
    expect(matches, [created.id, legacy.id]);
    expect(ids.where((id) => !matches.contains(id)), [
      'missing',
      deleted.id,
      other.id,
    ]);
  });

  test('legacy adoption preserves renamed and deleted rows', () async {
    final event = repo.tagEvents.first;
    final ids = await repo.adoptLegacyTags(['#Alpha', 'Alpha', 'Beta']);
    expect(ids, [Tag.legacyId('Alpha'), Tag.legacyId('Beta')]);
    expect((await event).fromSync, isTrue);
    expect(await repo.getTagById(ids.last), Tag.legacy('Beta'));
    await repo.renameTag('Alpha', 'Renamed');
    await repo.deleteTag('Beta');
    expect(await repo.adoptLegacyTags(['Alpha', 'Beta']), ids);
    final byId = await repo.getTagsByIds([...ids, 'missing']);
    expect(byId[ids.last]!.deleted, isTrue);
    expect(byId[ids.first]!.name, 'Renamed');
    expect((await repo.ensureTags(['Alpha'])).single, isNot(ids.first));
    expect(await repo.getAllTags(includeDeleted: true), hasLength(3));
  });

  test(
    'usage groups equal names and counts distinct visible diaries',
    () async {
      for (final (id, name) in [
        ('a', 'Alpha'),
        ('b', 'Alpha'),
        ('c', 'Beta'),
        ('d', 'Unused'),
      ]) {
        await repo.insertATag(Tag.legacy(name).copyWith(id: id));
      }
      final diaries = DiaryRepository(db);
      for (final (id, ids, time, show) in [
        ('first', ['a', 'b', 'c'], 1, true),
        ('second', ['a'], 3, true),
        ('hidden', ['b', 'd'], 9, false),
      ]) {
        await diaries.insertADiary(
          Diary.empty(type: .tiptap)
              .copyWith(id: id, tagIds: ids, time: dbToTime(time), show: show),
          index: .skip,
        );
      }
      final usage = await repo.getTagUsage();
      expect(usage.map((t) => (t.name, t.count, t.lastUsed)), [
        ('Alpha', 2, dbToTime(3)),
        ('Beta', 1, dbToTime(1)),
        ('Unused', 0, null),
      ]);
      expect(usage.first.ids, {'a', 'b'});
      expect(await repo.renameTag('Alpha', ' # Beta '), 2);
      expect((await repo.getTagUsage()).first.ids, {'a', 'b', 'c'});
      expect((await repo.getTagUsage()).first.count, 2);
      final lookup = await repo.getTagsByIds(['a', 'b', 'c']);
      expect(resolveTagNames(['unknown', 'b', 'a', 'c'], lookup), [
        (id: 'b', name: 'Beta'),
      ]);
      expect(await repo.deleteTag('Beta'), 3);
      expect((await repo.getTagUsage()).single.name, 'Unused');
      expect(resolveTagNames(['b'], await repo.getTagsByIds(['b'])), isEmpty);
    },
  );
}
