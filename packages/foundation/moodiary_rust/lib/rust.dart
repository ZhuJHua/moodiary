/// 桥本体：`RustLib.init()` 在 app 启动时调一次（见 main.dart）。
///
/// 只有组合根需要它。要调具体能力请走对应的门面（foundation / assistant /
/// export / sync / graph），别从这里拿。
library;

export 'src/rust/frb_generated.dart' show RustLib;
