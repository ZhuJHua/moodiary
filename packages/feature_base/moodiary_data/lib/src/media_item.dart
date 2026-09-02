import 'package:moodiary_models/moodiary_models.dart';

/// 媒体库的一行：一个媒体文件 + 它所属日记的身份与时间。按「日记时间倒序、
/// 日记 id 倒序、正文内次序」排，与 [DiaryRepository.getMediaItems] 的 ORDER BY 逐字段
/// 一致 —— 分页 offset 与事件增量都依赖两侧次序对齐。
class MediaItem {
  final String fileName;

  final String diaryId;

  /// 所属日记的 [Diary.time]（绝对时刻，展示分桶前 toLocal）。
  final DateTime time;

  const MediaItem({
    required this.fileName,
    required this.diaryId,
    required this.time,
  });

  static int compare(MediaItem a, MediaItem b) {
    final c = b.time.compareTo(a.time);
    return c != 0 ? c : b.diaryId.compareTo(a.diaryId);
  }
}
