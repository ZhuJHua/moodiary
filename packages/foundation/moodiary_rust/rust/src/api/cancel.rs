use flutter_rust_bridge::frb;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

/// 长任务的取消信号。被取消的调用以错误收场，调用方用 [Self::is_cancelled] 区分
/// 「取消」与「真失败」。只在循环边界生效——typst 的整篇排版会跑完当前这一趟。
#[frb(opaque)]
pub struct CancelToken {
    flag: Arc<AtomicBool>,
}

impl CancelToken {
    #[frb(sync)]
    pub fn new() -> CancelToken {
        CancelToken {
            flag: Arc::new(AtomicBool::new(false)),
        }
    }

    #[frb(sync)]
    pub fn cancel(&self) {
        self.flag.store(true, Ordering::Relaxed);
    }

    #[frb(sync)]
    pub fn is_cancelled(&self) -> bool {
        self.flag.load(Ordering::Relaxed)
    }
}

impl CancelToken {
    /// 子 crate 只认纯闭包，不认这个类型。
    pub(crate) fn checker(&self) -> impl Fn() -> bool + Send + Sync + 'static + use<> {
        let flag = self.flag.clone();
        move || flag.load(Ordering::Relaxed)
    }
}
