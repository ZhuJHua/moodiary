import 'place.dart';

/// 一次地点合并的撤销凭据，仅内存持有（toast 限时撤销窗口），不持久化。
/// 合并本身是单事务原子提交，凭据丢失只会失去撤销能力，不会留下脏数据。
class PlaceMergeRecord {
  /// 保留地点在合并前的原始快照，撤销时据此还原名称。
  final Place kept;

  /// 被合并删除的地点行（原 id / 原 lastModified），撤销时原样插回。
  final List<Place> removed;

  /// 受影响的日记：日记 id → 合并前指向的地点 id。
  final Map<String, String> diaryRemap;

  /// 合并前的常用地点排序，撤销时还原。
  final List<String> placeOrder;

  const PlaceMergeRecord({
    required this.kept,
    required this.removed,
    required this.diaryRemap,
    required this.placeOrder,
  });
}
