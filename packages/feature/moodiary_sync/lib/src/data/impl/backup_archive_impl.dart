import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';

import 'local_archive.dart';

/// [IBackupArchive] 的同步引擎实现。
///
/// 归档实现在 sync、页面在 export —— 两个 feature 不能互相 import，接线只能由
/// 组合根完成；类自注册后这条知识就落在实现类上，app 不必再认识两边。
@LazySingleton(as: IBackupArchive)
class SyncBackupArchive implements IBackupArchive {
  const SyncBackupArchive();

  @override
  Future<String> export() => LocalArchive.export();

  @override
  Future<String> import(String zipPath) async {
    final report = await LocalArchive.import(zipPath);
    return report.toString();
  }
}
