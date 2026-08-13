/// Moodiary 基建包（infra）：DI、存储（Isar/KV/Secure）、文件与缓存、媒体管线、
/// 网络、平台服务、全局主题与字体、日志、values。依赖 foundation 包（l10n/models/rust/utils）。
///
/// 目录按职责划分（files / media / network / storage / theme / values），不设 utils 杂物袋：
/// 新代码放进对应职责目录，放不进去说明它多半不属于基建层。
library;

export 'package:cross_file/cross_file.dart';
// 只放出 harmonizeWith：上层要把自定义色（分类色等）向主色靠拢，插件与取色部分不外泄。
export 'package:dynamic_color/dynamic_color.dart' show ColorHarmonization;
// 下沉到 utils 的薄 token/工具，经此转发保持既有 import 不变。
export 'package:moodiary_utils/moodiary_utils.dart'
    show
        AppBorderRadius,
        DeviceOrientationPolicy,
        KeyboardState,
        applyDeviceOrientationLock;

export 'src/app_logger.dart';
export 'src/backup_archive.dart';
export 'src/di.dart';
export 'src/file_picker.dart';
export 'src/files/app_files.dart';
export 'src/files/cache_store.dart';
export 'src/init.dart';
export 'src/media/audio_duration.dart';
export 'src/media/media_manager.dart';
export 'src/network/http_client.dart';
export 'src/network/http_server.dart';
export 'src/network/impl/rust_http_client.dart';
export 'src/network/impl/rust_http_server.dart';
export 'src/platform_service.dart';
export 'src/storage.dart';
export 'src/storage/database/isar.dart';
export 'src/storage/kv/pref.dart';
export 'src/storage/kv/secure.dart';
export 'src/theme/app_color_scheme.dart';
export 'src/theme/font_manager.dart';
export 'src/theme/theme_manager.dart';
export 'src/values/colors.dart';
export 'src/values/diary_sort.dart';
export 'src/values/expection.dart';
export 'src/values/kv.dart';
export 'src/values/language.dart';
export 'src/values/media_type.dart';
export 'src/values/search.dart';
export 'src/values/size.dart';
export 'src/values/view_mode.dart';
