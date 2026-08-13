import 'package:flutter/widgets.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'minimal_card.dart';
import 'note_card.dart';

/// 分享卡片的逻辑宽度（导出按此宽 × pixelRatio 出图，保证不同设备产出一致）。
const double kShareCardWidth = 360;

/// 一个分享卡片模版：自带排版、吃一个 [Diary] + 明暗 [Brightness] 渲染成固定宽度的卡片。
/// 新增模版 = 往 [kShareTemplates] 里加一项，其余代码零改动。
class ShareCardTemplate {
  final String id;

  /// 模版列表是顶层常量、拿不到 `BuildContext`，所以名称是个取串函数而不是字面量。
  final String Function(Translations l10n) label;
  final Widget Function(Diary diary, Brightness brightness) builder;

  const ShareCardTemplate({
    required this.id,
    required this.label,
    required this.builder,
  });
}

/// 已注册的模版（顺序即选择条顺序）。
final List<ShareCardTemplate> kShareTemplates = [
  ShareCardTemplate(
    id: 'minimal',
    label: (l10n) => l10n.share.templateMinimal,
    builder: (d, b) => MinimalShareCard(diary: d, brightness: b),
  ),
  ShareCardTemplate(
    id: 'note',
    label: (l10n) => l10n.share.templateNote,
    builder: (d, b) => NoteShareCard(diary: d, brightness: b),
  ),
];
