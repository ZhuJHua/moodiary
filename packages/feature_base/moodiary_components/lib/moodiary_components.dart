/// Moodiary 的**业务组件**。
///
/// 与 `package:mui` 的分界是一句话：**mui 不认识日记，本包认识**。
/// 业务无关的组件全在 mui（零 `moodiary_*` 依赖的 foundation 叶子包）；落在这里的
/// 是够不着它的那些——要 core 的基建（AppFiles / IHttpClient / MediaManager /
/// MoodiaryKVs / logger）或 riverpod，或者要认识领域类型。
///
/// 本包属 feature_base 层：features 共用它，它不认识任何具体 feature。
library;

// 组件与主题都从 mui 出，业务代码只需 import 本包或 mui。
export 'package:mui/mui.dart';

export 'src/common/async_value.dart';
export 'src/common/audio/audio_player_page.dart';
export 'src/common/audio_player.dart';
export 'src/common/frosted_glass_overlay.dart';
export 'src/common/image_browser.dart';
export 'src/common/mood_icon.dart';
export 'src/common/video/video_fullscreen_page.dart';
export 'src/mood_colors.dart';
