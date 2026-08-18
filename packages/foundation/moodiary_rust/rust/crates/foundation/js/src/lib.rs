//! 受限的 JavaScript 求值：给助手当「跑一段脚本」的工具用。
//!
//! 读者是模型，模型写的代码不可信 —— 不是恶意，而是**跑飞是常态**：一个
//! `while(true)` 或者一次巨大分配就是日常。所以这里唯一对外的构造入口
//! [`JsSandbox::new`] 强制装齐三道闸门（内存 / 栈 / 截止时间），不给「忘了设」
//! 留出可能。
//!
//! 沙箱里**什么都没有**：没有 fetch、没有定时器、没有文件系统、没有宿主绑定。
//! 模型只能算它自己写进代码里的值。要让它读日记，那是另一个决定，不在这一层。

use std::cell::RefCell;
use std::rc::Rc;
use std::time::{Duration, Instant};

use anyhow::{Result, anyhow};
use rquickjs::{CatchResultExt, Context, Function, Runtime, Value};

/// 三道闸门 + 输出上限。
#[derive(Debug, Clone, Copy)]
pub struct JsLimits {
    pub memory_bytes: usize,
    pub stack_bytes: usize,
    pub timeout: Duration,
    /// 结果与日志各自的字节上限。
    ///
    /// **这一条不是节俭，是止损**：工具结果要回灌进模型上下文并计费，而
    /// `while(true) console.log(x)` 在超时触发之前能产出好几 MB。
    pub max_output_bytes: usize,
}

impl Default for JsLimits {
    fn default() -> Self {
        Self {
            memory_bytes: 32 * 1024 * 1024,
            stack_bytes: 512 * 1024,
            timeout: Duration::from_secs(2),
            max_output_bytes: 4000,
        }
    }
}

/// 一次求值的结果。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JsOutcome {
    /// 最后一个表达式的值。对象走 `JSON.stringify`，`undefined` 为空串。
    pub value: String,
    /// `console.log` / `info` / `warn` / `error` 收集到的行，带级别前缀。
    pub logs: Vec<String>,
    /// 结果或日志被截断过。
    pub truncated: bool,
}

/// 一次性的求值器。**每次调用新建一个**，跑完即弃：QuickJS 的 runtime 不是
/// `Send`（`unsafe impl` 挂在 `parallel` feature 上，我们没开），复用它等于要在
/// 线程之间搬运一个不能搬的东西。
pub struct JsSandbox {
    context: Context,
    limits: JsLimits,
}

impl JsSandbox {
    /// 唯一入口。三道闸门在这里一次装齐 —— 拆成三个可选的 setter 就意味着某条
    /// 代码路径会建出一个没有上限的 runtime，而那种缺陷没有任何症状。
    pub fn new(limits: JsLimits) -> Result<Self> {
        let runtime = Runtime::new().map_err(|e| anyhow!("js runtime: {e}"))?;
        runtime.set_memory_limit(limits.memory_bytes);
        runtime.set_max_stack_size(limits.stack_bytes);

        // 截止时间在建 runtime 时就起算，把编译时间也算进去：一段病态的巨型源码
        // 光解析就能耗掉预算，那也是跑飞。
        let deadline = Instant::now() + limits.timeout;
        // **协作式，不是抢占式**：这个回调由解释器线程在字节码边界自己轮询，外部
        // 杀不掉。碰不到边界的地方（灾难性回溯的正则、一次巨大分配）它就不会触发，
        // 内存上限是后者的兜底，前者仍是敞着的延迟风险。
        runtime.set_interrupt_handler(Some(Box::new(move || Instant::now() >= deadline)));

        let context = Context::full(&runtime).map_err(|e| anyhow!("js context: {e}"))?;
        Ok(Self { context, limits })
    }

    /// 求值，返回最后一个表达式的值 —— 与 rikkahub 的 `eval_javascript` 同一个约定，
    /// 模型对它很熟：写 `1 + 2` 就该拿到 `3`，不必自己 `return`。
    pub fn eval(&self, code: &str) -> Result<JsOutcome> {
        let logs: Rc<RefCell<Vec<String>>> = Rc::new(RefCell::new(Vec::new()));
        let limits = self.limits;

        self.context.with(|ctx| {
            install_console(&ctx, &logs)?;

            let value: Value = ctx
                .eval::<Value, _>(code)
                .catch(&ctx)
                .map_err(|e| anyhow!("{e}"))?;

            let rendered = render(&ctx, &value)?;
            let (value, value_cut) = clamp(rendered, limits.max_output_bytes);
            let (logs, logs_cut) = clamp_logs(logs.borrow().clone(), limits.max_output_bytes);
            Ok(JsOutcome {
                value,
                logs,
                truncated: value_cut || logs_cut,
            })
        })
    }
}

/// 把 `console` 装进全局。**只装这一个** —— 沙箱里其余什么都没有是设计，不是遗漏。
fn install_console(ctx: &rquickjs::Ctx<'_>, logs: &Rc<RefCell<Vec<String>>>) -> Result<()> {
    let console = rquickjs::Object::new(ctx.clone()).map_err(|e| anyhow!("{e}"))?;
    for level in ["log", "info", "warn", "error"] {
        let sink = Rc::clone(logs);
        let tag = level.to_uppercase();
        let f = Function::new(ctx.clone(), move |args: rquickjs::function::Rest<Value>| {
            let line = args
                .iter()
                .map(|v| plain(v))
                .collect::<Vec<_>>()
                .join(" ");
            sink.borrow_mut().push(format!("[{tag}] {line}"));
        })
        .map_err(|e| anyhow!("{e}"))?;
        console.set(level, f).map_err(|e| anyhow!("{e}"))?;
    }
    ctx.globals()
        .set("console", console)
        .map_err(|e| anyhow!("{e}"))
}

/// 结果值 → 文本。对象走 `JSON.stringify`，别的走它自己的字符串化。
fn render<'js>(ctx: &rquickjs::Ctx<'js>, value: &Value<'js>) -> Result<String> {
    if value.is_undefined() {
        return Ok(String::new());
    }
    if value.is_object() || value.is_array() {
        // 循环引用会让 stringify 抛，此时退回普通字符串化而不是整个失败 ——
        // 拿到 `[object Object]` 也比拿到一句报错强。
        if let Ok(Some(s)) = ctx.json_stringify(value.clone())
            && let Ok(s) = s.to_string()
        {
            return Ok(s);
        }
    }
    Ok(plain(value))
}

fn plain(value: &Value<'_>) -> String {
    value
        .clone()
        .into_string()
        .and_then(|s| s.to_string().ok())
        .or_else(|| {
            value
                .as_number()
                .map(|n| if n.fract() == 0.0 { format!("{n:.0}") } else { n.to_string() })
        })
        .or_else(|| value.as_bool().map(|b| b.to_string()))
        .unwrap_or_else(|| {
            if value.is_null() {
                "null".to_string()
            } else if value.is_undefined() {
                "undefined".to_string()
            } else {
                format!("{value:?}")
            }
        })
}

/// 按**字节**截断，且不切碎字符。
fn clamp(text: String, max_bytes: usize) -> (String, bool) {
    if text.len() <= max_bytes {
        return (text, false);
    }
    let mut end = max_bytes;
    while end > 0 && !text.is_char_boundary(end) {
        end -= 1;
    }
    (text[..end].to_string(), true)
}

fn clamp_logs(logs: Vec<String>, max_bytes: usize) -> (Vec<String>, bool) {
    let mut out = Vec::new();
    let mut used = 0usize;
    for line in logs {
        if used + line.len() > max_bytes {
            return (out, true);
        }
        used += line.len() + 1;
        out.push(line);
    }
    (out, false)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(code: &str) -> Result<JsOutcome> {
        JsSandbox::new(JsLimits::default())?.eval(code)
    }

    #[test]
    fn returns_the_last_expression() {
        assert_eq!(run("1 + 2").unwrap().value, "3");
        assert_eq!(run("const x = 5; x * 2").unwrap().value, "10");
        assert_eq!(run("'hi'").unwrap().value, "hi");
    }

    #[test]
    fn objects_come_back_as_json() {
        assert_eq!(run("({a: 1, b: [2, 3]})").unwrap().value, r#"{"a":1,"b":[2,3]}"#);
    }

    #[test]
    fn console_is_captured_separately_from_the_value() {
        let out = run("console.log('a', 1); console.warn('b'); 42").unwrap();
        assert_eq!(out.value, "42");
        assert_eq!(out.logs, vec!["[LOG] a 1", "[WARN] b"]);
    }

    #[test]
    fn a_runaway_loop_is_cut_at_the_deadline() {
        let limits = JsLimits {
            timeout: Duration::from_millis(120),
            ..JsLimits::default()
        };
        let started = Instant::now();
        let err = JsSandbox::new(limits).unwrap().eval("while (true) {}");
        assert!(err.is_err(), "runaway loop must not return normally");
        // 松一点的上界：中断只在字节码边界轮询，不是精确的。
        assert!(started.elapsed() < Duration::from_secs(2), "interrupt never fired");
    }

    #[test]
    fn an_allocation_bomb_hits_the_memory_cap_instead_of_the_oom_killer() {
        let limits = JsLimits {
            memory_bytes: 2 * 1024 * 1024,
            ..JsLimits::default()
        };
        let out = JsSandbox::new(limits)
            .unwrap()
            .eval("const a = []; while (true) { a.push(new Array(10000).fill(0)); } a.length");
        assert!(out.is_err());
    }

    #[test]
    fn the_sandbox_has_no_host_capabilities() {
        // 一条都不能有：装上任何一个都等于给注入的指令开了一条腿。
        for probe in [
            "typeof fetch",
            "typeof setTimeout",
            "typeof require",
            "typeof process",
            "typeof XMLHttpRequest",
        ] {
            assert_eq!(run(probe).unwrap().value, "undefined", "{probe} must not exist");
        }
    }

    #[test]
    fn a_syntax_error_is_an_error_not_a_value() {
        assert!(run("const = = =").is_err());
    }

    #[test]
    fn output_is_capped() {
        let limits = JsLimits {
            max_output_bytes: 64,
            ..JsLimits::default()
        };
        let out = JsSandbox::new(limits).unwrap().eval("'x'.repeat(10000)").unwrap();
        assert_eq!(out.value.len(), 64);
        assert!(out.truncated);
    }

    #[test]
    fn truncation_does_not_split_a_character() {
        let limits = JsLimits {
            max_output_bytes: 7,
            ..JsLimits::default()
        };
        // 每个汉字 3 字节：7 字节只装得下 2 个。
        let out = JsSandbox::new(limits).unwrap().eval("'搬家后的'").unwrap();
        assert_eq!(out.value, "搬家");
        assert!(out.truncated);
    }
}
