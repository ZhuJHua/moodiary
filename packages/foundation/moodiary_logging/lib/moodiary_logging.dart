/// 应用日志。
///
/// release 下的落盘路径由组合根经 [AppLogger.configure] 注入，所以本包不认识文件
/// 布局——这也是它能待在 foundation（而不必上浮到 core）的全部原因。
library;

export 'src/app_logger.dart';
