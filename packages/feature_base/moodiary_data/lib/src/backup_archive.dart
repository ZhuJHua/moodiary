import 'package:moodiary_di/moodiary_di.dart';

/// 本地备份归档（整库 zip）的进出口。
///
/// 实现在 moodiary_sync（复用它的增量引擎与清单），消费方在 moodiary_export 的
/// 「导入与导出」页 —— 两者都是 feature 层、互相不能 import，故契约下沉到这里，
/// 由 app 层在 DI 里把 sync 的实现接上（同 [IFilePicker] / [IHttpClient] 的做法）。
abstract class IBackupArchive {
  static IBackupArchive get() => getIt.get<IBackupArchive>();

  /// 打包全部日记与媒体，返回生成的 zip 路径。
  Future<String> export();

  /// 从 zip 恢复，按「最后修改时间」与本地数据合并。返回一句可直接展示的结果摘要。
  Future<String> import(String zipPath);
}
