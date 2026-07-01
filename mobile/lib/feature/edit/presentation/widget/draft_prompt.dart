import 'package:flutter/material.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/app/router/router.dart';

/// FAB「新建日记」入口。创建即落盘：先插入一条空日记拿到真实 id，再打开编辑器。
/// 没写内容就退出也会留下一条记录——刻意淡化保存动作，让记录更自然。
Future<void> openNewDiaryEditor(BuildContext context, DiaryType type) async {
  final diary = Diary.empty(type: type);
  await DiaryRepository.get().insertADiary(diary);
  if (!context.mounted) return;
  _openDiary(context, type, diary.id);
}

void _openDiary(BuildContext context, DiaryType type, String id) {
  final route = DiaryRoute(type: type, diaryId: id, edit: true);
  route.push(context);
}
