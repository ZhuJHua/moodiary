use anyhow::Result;
use flutter_rust_bridge::frb;
use moodiary_js::{JsLimits, JsSandbox};

// mirror 的类型必须公开重导出：生成的代码按 `crate::api::js::JsOutcome` 引用它。
pub use moodiary_js::JsOutcome;

#[frb(mirror(JsOutcome))]
pub struct _JsOutcome {
    /// 最后一个表达式的值。对象是 `JSON.stringify` 后的文本，`undefined` 为空串。
    pub value: String,
    /// `console.log` / `info` / `warn` / `error` 的行，带 `[LOG]` 一类前缀。
    pub logs: Vec<String>,
    /// 结果或日志超了上限、被截断过。
    pub truncated: bool,
}

/// 跑一段 JavaScript，返回最后一个表达式的值。
///
/// **上限不过桥，全在 Rust 侧钉死**（见 [`JsLimits::default`]）。让 Dart 传进来
/// 就等于让每个调用点都有机会传出一个没有上限的沙箱，而那种缺陷在界面上没有症状。
///
/// 同步执行、跑完即弃：QuickJS 的 runtime 不是 `Send`，它在这一次调用的工作线程上
/// 生死，不跨 `await`、不复用。
pub fn js_eval(code: String) -> Result<JsOutcome> {
    JsSandbox::new(JsLimits::default())?.eval(&code)
}
