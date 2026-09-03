/// 快速压印：把导出 IR（[IrDoc]）压成 PDF（typst）或 DOCX（OOXML）。
/// 原生侧是自带的 `libfastpress`，经 flutter_rust_bridge 调用。
///
/// 用法：任何调用前先 `await FastPress.ensureInitialized()`（含 [CancelToken] 这类同步构造）；
/// 之后 [writePdf] / [writeDocx]，或逐篇推的 [PdfBuilder] / [DocxBuilder]。
library;

export 'src/runtime.dart';
export 'src/rust/api/cancel.dart';
export 'src/rust/api/docx.dart';
export 'src/rust/api/ir.dart';
export 'src/rust/api/pdf.dart';
export 'src/rust/frb_generated.dart' show FastPressLib;
