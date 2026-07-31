import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 一篇日记在列表里应当**展示**的时间戳（本地时区）。
///
/// 它必须跟着排序键走：按「最近修改」排序时列表顺序由 lastModified 决定，
/// 若行内仍显示 time，用户看到的就是一列日期完全无序的条目。
/// 时间线还额外拿它当分组键——分组键与排序键不一致会让月份吸顶头重复且乱序。
DateTime diaryStampOf(Diary diary, DiarySort sort) =>
    (sort == DiarySort.lastModifiedDesc ? diary.lastModified : diary.time)
        .toLocal();
