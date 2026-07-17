import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/incremental_engine.dart';

/// 启动墓碑保留窗 GC：在同步操作锁内执行，避免与在飞 push 的墓碑批量落库交错
/// （竞态本身无害——最坏短暂复活一条已超窗的墓碑行——加锁让它彻底不发生）。
Future<int> purgeExpiredTombstones() => IncrementalSyncEngine.runExclusive(
  () => TombstoneRepository.get().purgeExpired(),
);
