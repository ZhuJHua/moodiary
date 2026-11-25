import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';

Future<int> purgeExpiredTombstones(TombstoneRepository repository) =>
    IncrementalSyncEngine.runExclusive(() => repository.purgeExpired());
