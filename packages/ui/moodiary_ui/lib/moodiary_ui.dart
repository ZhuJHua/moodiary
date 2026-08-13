/// Moodiary 的 UI 层。
///
/// 业务无关的组件已经全部搬进 `package:mui`（本包转发它，调用方一个 import 就够）；
/// 留在这里的是**够不着 mui 的那几个**——它们要 core 的基建（AppFiles / IHttpClient /
/// MediaManager / MoodiaryKVs / logger）或 riverpod，而 mui 是零 moodiary_* 依赖的
/// foundation 叶子包。
library;

// 组件与主题都从 mui 出，业务代码只需 import 本包或 mui。
export 'package:mui/mui.dart';

export 'src/basic/image.dart';
export 'src/common/async_value.dart';
export 'src/common/audio/audio_player_page.dart';
export 'src/common/audio_player.dart';
export 'src/common/frosted_glass_overlay.dart';
export 'src/common/image_browser.dart';
export 'src/common/mood_icon.dart';
export 'src/common/video/video_fullscreen_page.dart';
