import 'package:moodiary_models/moodiary_models.dart';

import 'diary_content.dart';

/// 重算媒体三列（imageName / videoName / audioName = 正文里的媒体引用）。
/// 写入方改动 content 后必须过这一道，否则媒体库出幻影条目、废弃媒体永不回收
/// ——同一套重算此前在编辑器与助手各抄一遍。单次解析（DiaryContent 内部 late 派生）。
Diary withDerivedMedia(Diary d) {
  final media = DiaryContent.of(d).media;
  return d.copyWith(
    imageName: media.images,
    videoName: media.videos,
    audioName: media.audios,
  );
}

/// 用户编辑的时钟推进：bump lastModified（同步 LWW 的裁决字段）。
/// 派生写入（同步落库 / 迁移 / 修复）**不得**调用——那会把非编辑当成编辑，
/// 凭空赢下 LWW、覆盖他端的真实编辑。
Diary touched(Diary d) => d.copyWith(lastModified: .timestamp());
