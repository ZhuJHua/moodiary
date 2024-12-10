import 'package:mood_diary/utils/auth_util.dart';
import 'package:mood_diary/utils/cache_util.dart';
import 'package:mood_diary/utils/data/isar.dart';
import 'package:mood_diary/utils/data/pref.dart';
import 'package:mood_diary/utils/data/supabase.dart';
import 'package:mood_diary/utils/file_util.dart';
import 'package:mood_diary/utils/http_util.dart';
import 'package:mood_diary/utils/layout_util.dart';
import 'package:mood_diary/utils/log_util.dart';
import 'package:mood_diary/utils/media_util.dart';
import 'package:mood_diary/utils/notice_util.dart';
import 'package:mood_diary/utils/package_util.dart';
import 'package:mood_diary/utils/permission_util.dart';
import 'package:mood_diary/utils/signature_util.dart';
import 'package:mood_diary/utils/theme_util.dart';
import 'package:mood_diary/utils/update_util.dart';
import 'package:mood_diary/utils/webdav_util.dart';

import 'array_util.dart';

class Utils {
  Utils._();

  static final Utils _instance = Utils._();

  factory Utils() => _instance;

  late final ArrayUtil arrayUtil = ArrayUtil();

  late final AuthUtil authUtil = AuthUtil();

  late final CacheUtil cacheUtil = CacheUtil();

  late final FileUtil fileUtil = FileUtil();

  late final HttpUtil httpUtil = HttpUtil();

  late final LogUtil logUtil = LogUtil();

  late final LayoutUtil layoutUtil = LayoutUtil();

  late final MediaUtil mediaUtil = MediaUtil();

  late final NoticeUtil noticeUtil = NoticeUtil();

  late final PackageUtil packageUtil = PackageUtil();

  late final PermissionUtil permissionUtil = PermissionUtil();

  late final SignatureUtil signatureUtil = SignatureUtil();

  late final ThemeUtil themeUtil = ThemeUtil();

  late final UpdateUtil updateUtil = UpdateUtil();

  late final IsarUtil isarUtil = IsarUtil();

  late final PrefUtil prefUtil = PrefUtil();

  late final SupabaseUtil supabaseUtil = SupabaseUtil();

  late final WebDavUtil webDavUtil = WebDavUtil();
}
