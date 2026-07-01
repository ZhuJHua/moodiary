import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/sync/data/tombstone_tracker.dart';

import '../sync_test_harness.dart';

void main() {
  late MemoryKVStorage kv;

  setUp(() async {
    kv = (await setUpSyncEnv()).kv;
  });
  tearDown(tearDownSyncEnv);

  test('empty store reports no pushed backends', () {
    final t = TombstoneTracker.load();
    expect(t.pushedFor('x'), isEmpty);
  });

  test('markPushed accumulates per diary and survives a save/reload', () async {
    final t = TombstoneTracker.load();
    t.markPushed('d1', 'webdav');
    t.markPushed('d1', 's3');
    t.markPushed('d2', 'webdav');
    await t.save();

    final reloaded = TombstoneTracker.load();
    expect(reloaded.pushedFor('d1'), {'webdav', 's3'});
    expect(reloaded.pushedFor('d2'), {'webdav'});
    expect(reloaded.pushedFor('d1').containsAll({'webdav', 's3'}), isTrue);
  });

  test('clear removes a diary from the table', () async {
    final t = TombstoneTracker.load();
    t.markPushed('d1', 'webdav');
    t.clear(['d1']);
    await t.save();
    expect(TombstoneTracker.load().pushedFor('d1'), isEmpty);
  });

  test('save is a no-op when nothing changed (does not touch KV)', () async {
    final t = TombstoneTracker.load();
    await t.save();
    expect(kv.data.containsKey(MoodiaryKVs.tombstonePushedBackends.name), isFalse);
  });

  test('clearing the last entry writes an empty object back', () async {
    final t = TombstoneTracker.load();
    t.markPushed('d1', 'webdav');
    await t.save();
    t.clear(['d1']);
    await t.save();
    expect(MoodiaryKVs.tombstonePushedBackends.get(), '{}');
  });

  test('malformed KV content is tolerated as an empty table', () async {
    await MoodiaryKVs.tombstonePushedBackends.set('not json');
    expect(TombstoneTracker.load().pushedFor('d1'), isEmpty);

    await MoodiaryKVs.tombstonePushedBackends.set('[1,2,3]');
    expect(TombstoneTracker.load().pushedFor('d1'), isEmpty);
  });
}
