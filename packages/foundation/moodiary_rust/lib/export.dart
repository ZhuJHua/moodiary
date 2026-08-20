/// 导出能力：PDF（typst）、DOCX，以及两者共用的导出 IR。
///
/// **只有 `moodiary_export` 可以导入本门面**（闸门在 tool/check_layers.dart）。
/// 它也是整个原生库里最重的一块，别让它渗进别的包。
library;

export 'src/rust/api/docx.dart';
export 'src/rust/api/export_ir.dart';
export 'src/rust/api/pdf.dart';
