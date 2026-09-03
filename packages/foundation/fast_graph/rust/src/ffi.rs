//! C ABI 门面：本 crate 唯一带 `unsafe` 的地方。
//!
//! 一次布局 = [`fastgraph_layout_start`] 起一条线程跑 [`crate::layout::layout_graph_stream`]，
//! 每帧经 `cb(kind, ptr, len)` 推给 Dart：`kind` 0 = 帧（`f32` 的原生字节序，`len` 是字节数）、
//! 1 = 沉降完成、2 = 错误（UTF-8 文本）。**终态事件（1 / 2）恰好来一次**，取消也不例外——
//! Dart 侧要等到它再关掉 `NativeCallable`。载荷都是 Rust 堆上的 boxed slice，由
//! [`fastgraph_buf_free`] 归还。线程内整体 `catch_unwind`：panic 越过 FFI 边界是 UB。

use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::layout::{GraphLayoutParams, layout_graph_stream};

pub type FrameCallback = unsafe extern "C" fn(kind: i32, ptr: *const u8, len: usize);

const KIND_FRAME: i32 = 0;
const KIND_DONE: i32 = 1;
const KIND_ERROR: i32 = 2;

/// [`GraphLayoutParams`] 的 C 镜像；字段一一对应，`normalize_scale` 用 0 / 1。
#[repr(C)]
pub struct FfiLayoutParams {
    pub iterations: u32,
    pub theta: f32,
    pub repulsion: f32,
    pub spring_length: f32,
    pub spring_strength: f32,
    pub gravity: f32,
    pub collide_radius: f32,
    pub velocity_decay: f32,
    pub emit_every: u32,
    pub frame_delay_ms: u32,
    pub initial_alpha: f32,
    pub min_step: f32,
    pub pinned_count: u32,
    pub normalize_scale: u8,
}

impl FfiLayoutParams {
    fn to_params(&self) -> GraphLayoutParams {
        GraphLayoutParams {
            iterations: self.iterations,
            theta: self.theta,
            repulsion: self.repulsion,
            spring_length: self.spring_length,
            spring_strength: self.spring_strength,
            gravity: self.gravity,
            collide_radius: self.collide_radius,
            velocity_decay: self.velocity_decay,
            emit_every: self.emit_every,
            frame_delay_ms: self.frame_delay_ms,
            initial_alpha: self.initial_alpha,
            min_step: self.min_step,
            pinned_count: self.pinned_count,
            normalize_scale: self.normalize_scale != 0,
        }
    }
}

/// 一次布局的句柄：只装取消标记；线程自己持有一份 Arc，句柄可以先于线程释放。
pub struct LayoutHandle {
    cancelled: Arc<AtomicBool>,
}

/// 把载荷交给 Dart：boxed slice（cap == len），[`fastgraph_buf_free`] 用 (ptr, len) 就能归还。
fn hand_over(bytes: Vec<u8>) -> (*const u8, usize) {
    let boxed = bytes.into_boxed_slice();
    let len = boxed.len();
    (Box::into_raw(boxed) as *const u8, len)
}

/// # Safety
/// `(ptr, len)` 必须来自本库某次回调的载荷，且只归还一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastgraph_buf_free(ptr: *mut u8, len: usize) {
    if ptr.is_null() {
        return;
    }
    drop(unsafe { Box::from_raw(std::ptr::slice_from_raw_parts_mut(ptr, len)) });
}

/// 起一次布局。输入在调用期间拷进 Rust，返回后 Dart 可以立刻释放它们。
///
/// # Safety
/// `edges` / `initial` 为空或长度为 0 视为空切片，否则必须指向足量元素；`params` 非空；
/// `cb` 在终态事件之前必须保持可调用。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastgraph_layout_start(
    node_count: u32,
    edges: *const i32,
    edges_len: usize,
    initial: *const f32,
    initial_len: usize,
    params: *const FfiLayoutParams,
    cb: FrameCallback,
) -> *mut LayoutHandle {
    let edges = if edges.is_null() || edges_len == 0 {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(edges, edges_len) }.to_vec()
    };
    let initial = if initial.is_null() || initial_len == 0 {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(initial, initial_len) }.to_vec()
    };
    let params = unsafe { &*params }.to_params();
    let cancelled = Arc::new(AtomicBool::new(false));
    let flag = cancelled.clone();

    std::thread::spawn(move || {
        let result = catch_unwind(AssertUnwindSafe(|| {
            layout_graph_stream(node_count, edges, initial, params, |frame| {
                if flag.load(Ordering::Relaxed) {
                    return false;
                }
                let mut bytes = Vec::with_capacity(frame.len() * 4);
                for v in frame {
                    bytes.extend_from_slice(&v.to_ne_bytes());
                }
                let (ptr, len) = hand_over(bytes);
                unsafe { cb(KIND_FRAME, ptr, len) };
                !flag.load(Ordering::Relaxed)
            })
        }));
        match result {
            Ok(Ok(())) => unsafe { cb(KIND_DONE, std::ptr::null(), 0) },
            Ok(Err(e)) => {
                let (ptr, len) = hand_over(e.to_string().into_bytes());
                unsafe { cb(KIND_ERROR, ptr, len) };
            }
            Err(p) => {
                let msg = p
                    .downcast_ref::<&str>()
                    .map(|s| (*s).to_owned())
                    .or_else(|| p.downcast_ref::<String>().cloned())
                    .unwrap_or_else(|| "unknown panic".to_owned());
                let (ptr, len) = hand_over(format!("panic: {msg}").into_bytes());
                unsafe { cb(KIND_ERROR, ptr, len) };
            }
        }
    });

    Box::into_raw(Box::new(LayoutHandle { cancelled }))
}

/// 请求取消：布局线程在下一帧边界退出，随后仍会发一次终态事件。
///
/// # Safety
/// `handle` 必须来自 [`fastgraph_layout_start`] 且尚未 free。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastgraph_layout_cancel(handle: *mut LayoutHandle) {
    if let Some(h) = unsafe { handle.as_ref() } {
        h.cancelled.store(true, Ordering::Relaxed);
    }
}

/// # Safety
/// `handle` 必须来自 [`fastgraph_layout_start`] 且只 free 一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastgraph_layout_free(handle: *mut LayoutHandle) {
    if !handle.is_null() {
        drop(unsafe { Box::from_raw(handle) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;
    use std::time::Duration;

    static EVENTS: Mutex<Vec<(i32, Vec<u8>)>> = Mutex::new(Vec::new());

    unsafe extern "C" fn collect(kind: i32, ptr: *const u8, len: usize) {
        let bytes = if ptr.is_null() {
            Vec::new()
        } else {
            unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec()
        };
        unsafe { fastgraph_buf_free(ptr as *mut u8, len) };
        EVENTS.lock().unwrap().push((kind, bytes));
    }

    fn params(iterations: u32) -> FfiLayoutParams {
        FfiLayoutParams {
            iterations,
            theta: 0.9,
            repulsion: 1.0,
            spring_length: 30.0,
            spring_strength: 0.1,
            gravity: 0.05,
            collide_radius: 8.0,
            velocity_decay: 0.4,
            emit_every: 1,
            frame_delay_ms: 0,
            initial_alpha: 1.0,
            min_step: 0.0,
            pinned_count: 0,
            normalize_scale: 1,
        }
    }

    fn wait_terminal() -> Vec<(i32, Vec<u8>)> {
        for _ in 0..200 {
            std::thread::sleep(Duration::from_millis(10));
            let events = EVENTS.lock().unwrap();
            if events.iter().any(|(k, _)| *k != KIND_FRAME) {
                return events.clone();
            }
        }
        panic!("没有等到终态事件");
    }

    #[test]
    fn frames_then_done_over_the_c_abi() {
        EVENTS.lock().unwrap().clear();
        let edges = [0i32, 1, 1, 2];
        let handle = unsafe {
            fastgraph_layout_start(
                3,
                edges.as_ptr(),
                4,
                std::ptr::null(),
                0,
                &params(5),
                collect,
            )
        };
        let events = wait_terminal();
        unsafe { fastgraph_layout_free(handle) };
        assert_eq!(events.last().map(|(k, _)| *k), Some(KIND_DONE));
        let frames: Vec<_> = events.iter().filter(|(k, _)| *k == KIND_FRAME).collect();
        assert!(!frames.is_empty());
        assert!(frames.iter().all(|(_, b)| b.len() == 3 * 2 * 4));
    }

    #[test]
    fn bad_edges_report_an_error_event() {
        EVENTS.lock().unwrap().clear();
        let edges = [0i32, 9];
        let handle = unsafe {
            fastgraph_layout_start(
                2,
                edges.as_ptr(),
                2,
                std::ptr::null(),
                0,
                &params(5),
                collect,
            )
        };
        let events = wait_terminal();
        unsafe { fastgraph_layout_free(handle) };
        let (kind, msg) = events.last().unwrap();
        assert_eq!(*kind, KIND_ERROR);
        assert!(String::from_utf8(msg.clone()).unwrap().contains("越界"));
    }
}
