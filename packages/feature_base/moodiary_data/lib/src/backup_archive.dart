import 'package:moodiary_di/moodiary_di.dart';

/// 本地备份归档的进出口。
///
/// **不是整库备份**，范围就是日记 + 分类 + 媒体元数据 + 日记引用到的媒体文件
/// （布局与远端归档同源，见 sync 的 LocalArchive）。助手会话 / 记忆 / 预设 /
/// 供应商配置、聊天里的图片、自定义字体、以及全部 KV 设置（含同步后端配置）
/// **都不在包里**，换机后需要重新配置。要改成整库，按现有 `<kind>/<id>.json`
/// 布局补写对应表与目录即可，恢复侧共用同一套 ArchiveApplier。
///
/// 实现在 moodiary_sync（复用它的增量引擎与清单），消费方在 moodiary_export 的
/// 「导入与导出」页 —— 两者都是 feature 层、互相不能 import，故契约下沉到这里，
/// 由 app 层在 DI 里把 sync 的实现接上（同 [IFilePicker] / [IHttpClient] 的做法）。
abstract class IBackupArchive {
  static IBackupArchive get() => getIt.get<IBackupArchive>();

  /// 打包全部日记与媒体（范围见类文档），返回生成的 zip 路径。
  Future<String> export();

  /// 从 zip 恢复，按「最后修改时间」与本地数据合并。
  /// 返回结构化结果——端口不返回展示串（那会把文案语言钉死在实现里，
  /// 英文界面弹中文 toast 就是这么来的），本地化由消费页自己组织。
  Future<BackupImportResult> import(String zipPath);
}

/// [IBackupArchive.import] 的结果。刻意不复用 sync 的 SyncReport——data 是
/// feature_base，不该认识 feature 的类型。
class BackupImportResult {
  final int diaryCount;

  final int categoryCount;

  final int mediaInfoCount;

  final int failed;

  /// 恢复被中途停止（进程级取消标志在恢复期间为真）：只导入了半截，
  /// 消费页不得按成功呈现。
  final bool cancelled;

  /// 因「本机内容不旧于备份」而跳过的条目数。要能和「备份已是最新」区分开 ——
  /// 两者此前显示的都是「恢复 0 条」。
  final int skipped;

  const BackupImportResult({
    required this.diaryCount,
    required this.categoryCount,
    required this.mediaInfoCount,
    required this.failed,
    this.cancelled = false,
    this.skipped = 0,
  });
}
