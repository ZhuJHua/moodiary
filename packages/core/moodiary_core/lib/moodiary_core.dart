/// Moodiary 基建包（infra）：DI、存储（Isar/KV/Secure）、网络、平台服务、
/// 全局主题/通知、values 与基建 utils。依赖 foundation 包（l10n/models/rust/utils）。
library;

export 'package:cross_file/cross_file.dart';
// 只放出 harmonizeWith：上层要把自定义色（分类色等）向主色靠拢，插件与取色部分不外泄。
export 'package:dynamic_color/dynamic_color.dart' show ColorHarmonization;
export 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
export 'package:font_awesome_flutter/font_awesome_flutter.dart';
// 下沉到 utils 的薄 token/工具，经此转发保持既有 import 不变。
export 'package:moodiary_utils/moodiary_utils.dart'
    show
        AppBorderRadius,
        DeviceOrientationPolicy,
        KeyboardState,
        ThemeExt,
        applyDeviceOrientationLock;

export 'src/di.dart';
export 'src/file_picker.dart';
export 'src/init.dart';
export 'src/network/http_client.dart';
export 'src/network/http_server.dart';
export 'src/network/impl/rust_http_client.dart';
export 'src/network/impl/rust_http_server.dart';
export 'src/platform_service.dart';
export 'src/storage.dart';
export 'src/storage/database/isar.dart';
export 'src/storage/kv/pref.dart';
export 'src/storage/kv/secure.dart';
export 'src/utils/cache_util.dart';
export 'src/utils/file_util.dart';
export 'src/utils/font_util.dart';
export 'src/utils/loadmore.dart';
export 'src/utils/log_util.dart';
export 'src/utils/media_util.dart';
export 'src/utils/notice_util.dart';
export 'src/utils/theme_util.dart';
export 'src/utils/widget_util.dart';
export 'src/values/colors.dart';
export 'src/values/diary_sort.dart';
export 'src/values/expection.dart';
export 'src/values/kv.dart';
export 'src/values/language.dart';
export 'src/values/media_type.dart';
export 'src/values/open_diary_registry.dart';
export 'src/values/search.dart';
export 'src/values/sync_pending.dart';
export 'src/values/size.dart';
export 'src/values/view_mode.dart';
