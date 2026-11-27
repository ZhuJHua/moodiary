import 'package:moodiary_models/moodiary_models.dart';

DateTime diaryStampOf(DiarySummary diary, DiarySort sort) =>
    (sort == .lastModifiedDesc ? diary.lastModified : diary.time).toLocal();
