import 'package:freezed_annotation/freezed_annotation.dart';

import 'utc_date_time_converter.dart';

part 'media_info.freezed.dart';
part 'media_info.g.dart';

/// 媒体文件的类型段：`audio-<uuid>.m4a` → `audio`。媒体文件统一以类型为前缀
/// 命名，远端 `mediainfo/<type>/` 子目录据此划分。无前缀的异常名归入 `other`。
String mediaTypeOfFileName(String fileName) {
  final i = fileName.indexOf('-');
  return i <= 0 ? 'other' : fileName.substring(0, i);
}

/// 媒体元数据行，随同步传播（LWW 时钟 [lastModified]，墓碑前缀 `m:`）。
/// 当前只有音频写入（名称 + 时长）；模型按媒体通用设计，将来视频等直接复用。
///
/// - [fileName] 即业务主键（`<type>-<uuidv7>.<ext>`），与日记正文节点的
///   filename attr 一一对应，正文本身不存名称——单一事实源在本表；
/// - [name] 为 null 表示未命名，显示层回退默认名（走 l10n），默认名不落盘；
/// - [durationMs] 创建时探测写入，缺行/缺值由懒补行回填，可重建。
@freezed
abstract class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    required String fileName,
    String? name,
    int? durationMs,
    @UtcDateTimeConverter() required DateTime lastModified,
  }) = _MediaInfo;

  const MediaInfo._();

  factory MediaInfo.create({
    required String fileName,
    String? name,
    int? durationMs,
  }) {
    return MediaInfo(
      fileName: fileName,
      name: name,
      durationMs: durationMs,
      lastModified: .timestamp(),
    );
  }

  String get mediaType => mediaTypeOfFileName(fileName);

  factory MediaInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoFromJson(json);
}
