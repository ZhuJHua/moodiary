import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';

Future<int> purgeExpiredTombstones() => IncrementalSyncEngine.runExclusive(
  () => getIt<TombstoneRepository>().purgeExpired(),
);
