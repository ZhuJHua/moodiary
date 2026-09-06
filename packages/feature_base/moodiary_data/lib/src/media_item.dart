class MediaItem {
  final String fileName;

  final String diaryId;

  final DateTime time;

  const MediaItem({
    required this.fileName,
    required this.diaryId,
    required this.time,
  });

  // 排序须与 DiaryRepository.getMediaItems 的 ORDER BY 逐字段一致，分页与事件增量都靠它对齐
  static int compare(MediaItem a, MediaItem b) {
    final c = b.time.compareTo(a.time);
    return c != 0 ? c : b.diaryId.compareTo(a.diaryId);
  }
}
