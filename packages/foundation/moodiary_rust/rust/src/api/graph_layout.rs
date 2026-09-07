use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::frb_generated::{FLUTTER_RUST_BRIDGE_HANDLER, StreamSink};

pub use crate::graph::layout::GraphLayoutParams;

#[frb(mirror(GraphLayoutParams))]
pub struct _GraphLayoutParams {
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
    pub normalize_scale: bool,
}

pub async fn layout_graph_stream(
    node_count: u32,
    edges: Vec<i32>,
    initial_positions: Vec<f32>,
    params: GraphLayoutParams,
    sink: StreamSink<Vec<f32>>,
) -> Result<()> {
    let error_sink = sink.clone();
    let result = flutter_rust_bridge::spawn_blocking_with(
        move || {
            crate::graph::layout::layout_graph_stream(
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
    if let Err(e) = result {
        let _ = error_sink.add_error(e);
    }
    Ok(())
}
