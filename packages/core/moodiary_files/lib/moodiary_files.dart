/// 文件布局与媒体管线：应用目录结构、媒体存取与缩略图派生、文件选择端口。
///
/// 媒体管线（[MediaManager]）就住在这里而不是单独成包：它干的事就是媒体文件的
/// 存盘、命名、派生与相册写入，与 [AppFiles] 同一职责。
library;

export 'package:cross_file/cross_file.dart';

export 'src/app_files.dart';
export 'src/audio_duration.dart';
export 'src/file_picker.dart';
export 'src/media_manager.dart';
export 'src/media_type.dart';
