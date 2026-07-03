import 'package:flutter/widgets.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'minimal_card.dart';
import 'note_card.dart';

/// 分享卡片的逻辑宽度（导出按此宽 × pixelRatio 出图，保证不同设备产出一致）。
const double kShareCardWidth = 360;

/// 一个分享卡片模版：自带配色/排版、吃一个 [Diary] 渲染成固定宽度的卡片。
/// 新增模版 = 往 [kShareTemplates] 里加一项，其余代码零改动。
class ShareCardTemplate {
  final String id;
  final String name;
  final Widget Function(Diary diary) builder;

  const ShareCardTemplate({
    required this.id,
    required this.name,
    required this.builder,
  });
}

/// 已注册的模版（顺序即选择条顺序）。
final List<ShareCardTemplate> kShareTemplates = [
  ShareCardTemplate(
    id: 'minimal',
    name: '简约',
    builder: (d) => MinimalShareCard(diary: d),
  ),
  ShareCardTemplate(
    id: 'note',
    name: '便签',
    builder: (d) => NoteShareCard(diary: d),
  ),
];
