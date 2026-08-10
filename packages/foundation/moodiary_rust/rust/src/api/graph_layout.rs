use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::frb_generated::{FLUTTER_RUST_BRIDGE_HANDLER, StreamSink};

pub use moodiary_graph::GraphLayoutParams;

#[frb(mirror(GraphLayoutParams))]
pub struct _GraphLayoutParams {
    pub iterations: u32,
    /// Barnes-Hut 开角：节点宽度 / 距离 < theta 时整簇当一个质点。越小越准越慢(~0.9)。
    pub theta: f32,
    /// FA2 斥力系数 kr。传 `spring_strength × (spring_length/2)²` 可让两个度数为 1 的
    /// 相连叶节点平衡距恰为 spring_length。
    pub repulsion: f32,
    /// 叶对目标距；同时用作单步位移上限。
    pub spring_length: f32,
    pub spring_strength: f32,
    /// 向心力，把彼此不连通的分量拉进视野。
    pub gravity: f32,
    /// d3 forceCollide 语义：节点视为半径 r 的圆盘，收敛后圆心最小间距≈2r。
    pub collide_radius: f32,
    /// d3 velocityDecay 语义：每步速度乘以 `1-velocity_decay`。越大越黏、越不易振荡。
    pub velocity_decay: f32,
    pub emit_every: u32,
    pub frame_delay_ms: u32,
    /// 起始 alpha(<=0 或 >1 视为 1.0)。增量重布局传 0.25~0.35，配合 initial_positions
    /// 让图原地微调而不是整体炸开重排。
    pub initial_alpha: f32,
    /// 提前退出阈值，单位 = spring_length 的倍数(<=0 表示跑满 iterations)。
    pub min_step: f32,
    /// 前 k 个下标的节点钉住不动(0 = 不钉)。ego 图把中心节点排在下标 0。
    pub pinned_count: u32,
    /// 对**发出的**坐标做尺度归一化：把相连节点距离的中位数缩放到 spring_length。
    /// 仿真空间不变，只换算发出的副本。
    pub normalize_scale: bool,
}

/// `edges` 为 `[src0,dst0,src1,dst1,...]` 密集下标对；`initial_positions` 为空则用
/// 黄金角螺旋确定性播种。每帧向 `sink` 推 `[x0,y0,...]`，函数返回即沉降完成。
pub async fn layout_graph_stream(
    node_count: u32,
    edges: Vec<i32>,
    initial_positions: Vec<f32>,
    params: GraphLayoutParams,
    sink: StreamSink<Vec<f32>>,
) -> Result<()> {
    let error_sink = sink.clone();
    // 仿真循环会在帧间 sleep，占着 FRB 那个固定 num_cpus 的池不划算，挪到 tokio 的
    // 弹性 blocking 池。
    let result = flutter_rust_bridge::spawn_blocking_with(
        move || {
            // sink.add 报错 = 下游已取消（离页 / 换筛选），内核据此立刻收尾。
            moodiary_graph::layout_graph_stream(
                node_count,
                edges,
                initial_positions,
                params,
                |frame| sink.add(frame).is_ok(),
            )
        },
        FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    )
    .await?;
    // 见 assistant.rs：Err 返回值到不了 Dart 的流，必须经 sink 下发。
    if let Err(e) = result {
        let _ = error_sink.add_error(e);
    }
    Ok(())
}
