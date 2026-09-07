use flutter_rust_bridge::frb;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

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
    pub(crate) fn checker(&self) -> impl Fn() -> bool + Send + Sync + 'static + use<> {
        let flag = self.flag.clone();
        move || flag.load(Ordering::Relaxed)
    }
}
