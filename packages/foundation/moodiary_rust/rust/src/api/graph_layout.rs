//! 知识图谱的力导向布局:**ForceAtlas2 力模型**(Jacomy 2014,Gephi 默认)+ Barnes-Hut
//! 四叉树加速(O(N log N))。斥力按度数加权(`kr·(deg₁+1)(deg₂+1)/d`,hub 周围自动更疏),
//! 边上为线性引力(无自然长,间距由力平衡涌现);两处刻意偏离原版:保留线性向心力(把
//! 不连通分量收进视野)与 forceCollide 碰撞(硬保不重叠)。积分器为 d3 式平滑退火。
//! 中间坐标经 [StreamSink] 逐帧回传;下游取消(离页/换筛选)时 `sink.add` 报错,循环即止。
//! 发帧前可做尺度归一化(见 [GraphLayoutParams::normalize_scale]),让任意规模的图在视图里
//! 保持同一「相连节点中位距」,避免大图缩到看不见。

use anyhow::{Result, anyhow};
use std::collections::HashMap;
use std::thread;
use std::time::Duration;

use crate::frb_generated::StreamSink;

/// 布局参数。Dart 侧给定,零值字段由 [normalized] 兜底成合理默认。
pub struct GraphLayoutParams {
    /// 最大迭代步数。
    pub iterations: u32,
    /// Barnes-Hut 开角:节点宽度 / 距离 < theta 时整簇当一个质点。越小越准越慢(~0.9)。
    pub theta: f32,
    /// FA2 斥力系数 kr。建议传 `spring_strength × (spring_length/2)²`,则两个度数为 1
    /// 的相连叶节点平衡距恰为 [spring_length](度数越高间距自动越大)。
    pub repulsion: f32,
    /// 叶对目标距(见 [repulsion] 的推导);同时用作单步位移上限。
    pub spring_length: f32,
    /// FA2 线性引力系数 ka(每条边 F = ka·d)。
    pub spring_strength: f32,
    /// 向心力,把彼此不连通的分量拉进视野。
    pub gravity: f32,
    /// 碰撞半径(世界单位,d3 forceCollide 语义):节点视为半径 r 的圆盘,每步把重叠对
    /// 推开,收敛后圆心最小间距≈2r。配合 UI 按 scale 绘制节点,任意缩放不重叠。
    pub collide_radius: f32,
    /// 速度衰减(0~1,d3 velocityDecay 语义):每步速度乘以 `1-velocity_decay`。越大越黏、
    /// 越不易振荡(过冲=抽搐感的来源),0.4 左右平滑。
    pub velocity_decay: f32,
    /// 每几步推一帧坐标。
    pub emit_every: u32,
    /// 每帧之后 sleep 的毫秒数,保证小图也「看得见」沉降过程。
    pub frame_delay_ms: u32,
    /// 起始 alpha(<=0 或 >1 视为 1.0)。增量重布局(数据刷新 / 换筛选)传 0.25~0.35,
    /// 配合 initial_positions 让图原地微调而不是整体炸开重排。
    pub initial_alpha: f32,
    /// 收敛提前退出阈值,单位 = spring_length 的倍数(<=0 表示跑满 iterations)。
    /// 建议 1e-3:连续 5 步最大位移低于它且 alpha 已衰减到 0.05 以下时收尾。
    pub min_step: f32,
    /// 前 k 个下标的节点钉住不动(0 = 不钉)。ego 图把中心节点排在下标 0。
    pub pinned_count: u32,
    /// 是否对**发出的**坐标做尺度归一化:把相连节点距离的中位数缩放到 spring_length。
    /// 仿真空间不变,只换算发出的副本;碰撞半径与单步位移上限同步按该因子放大,
    /// 使二者在归一化后的视图里恒等于传入值。
    pub normalize_scale: bool,
}

struct Params {
    iterations: u32,
    theta_sq: f32,
    repulsion: f32,
    spring_length: f32,
    spring_strength: f32,
    gravity: f32,
    collide_radius: f32,
    /// 每步保留的速度比例(= 1 - velocity_decay)。
    velocity_retain: f32,
    emit_every: u32,
    frame_delay_ms: u32,
    initial_alpha: f32,
    min_step: f32,
    pinned_count: usize,
    normalize_scale: bool,
}

impl GraphLayoutParams {
    fn normalized(&self) -> Params {
        let pos = |v: f32, d: f32| if v > 0.0 { v } else { d };
        let theta = pos(self.theta, 0.9);
        let decay = if self.velocity_decay > 0.0 && self.velocity_decay < 1.0 {
            self.velocity_decay
        } else {
            0.4
        };
        Params {
            iterations: if self.iterations > 0 { self.iterations } else { 400 },
            theta_sq: theta * theta,
            // 默认与 spring 默认(60, 0.08)自洽:kr = 0.08×(60/2)²。
            repulsion: pos(self.repulsion, 72.0),
            spring_length: pos(self.spring_length, 60.0),
            spring_strength: pos(self.spring_strength, 0.08),
            gravity: if self.gravity >= 0.0 { self.gravity } else { 0.02 },
            collide_radius: pos(self.collide_radius, 12.0),
            velocity_retain: 1.0 - decay,
            emit_every: if self.emit_every > 0 { self.emit_every } else { 1 },
            frame_delay_ms: self.frame_delay_ms,
            initial_alpha: if self.initial_alpha > 0.0 && self.initial_alpha <= 1.0 {
                self.initial_alpha
            } else {
                1.0
            },
            min_step: self.min_step.max(0.0),
            pinned_count: self.pinned_count as usize,
            normalize_scale: self.normalize_scale,
        }
    }
}

/// 距离过近时的软化项,避免斥力爆炸/除零。
const SOFTENING: f32 = 0.01;
/// 四叉树最大深度;坐标重合时防止无限细分。再深下去格宽已低于 f32 在该量级的间隔,
/// 象限判定失效,纯浪费 cell。
const MAX_DEPTH: u32 = 24;
/// 退火终点(d3 alphaMin 惯例值):alpha 几何衰减,恰在末次迭代降到此值。
const ALPHA_MIN: f32 = 0.001;
/// 播种螺旋的铺展基准(世界单位):半径随 √N 放大。
const SEED_SPREAD: f32 = 20.0;
/// 判定「已静止」所需的连续步数。
const STILL_STEPS: u32 = 5;
/// 早停只在退火尾段生效,避免高能阶段的瞬时低速误判。
const STILL_ALPHA: f32 = 0.05;

/// 流式布局。`edges` 为 `[src0,dst0,src1,dst1,...]` 密集下标对(无向,建议去重);
/// `initial_positions` 为空则用黄金角螺旋确定性播种。每帧向 `sink` 推 `[x0,y0,...]`
/// (长度 `2*node_count`);函数返回即流关闭,代表沉降完成。
pub fn layout_graph_stream(
    node_count: u32,
    edges: Vec<i32>,
    initial_positions: Vec<f32>,
    params: GraphLayoutParams,
    sink: StreamSink<Vec<f32>>,
) -> Result<()> {
    let n = node_count as usize;
    if !edges.len().is_multiple_of(2) {
        return Err(anyhow!("edges 长度必须为偶数(下标对)"));
    }
    for &e in &edges {
        if e < 0 || e as usize >= n {
            return Err(anyhow!("边下标越界: {e} (node_count={n})"));
        }
    }

    let mut pos = seed_positions(n, &initial_positions)?;

    // 平凡图:无需迭代,直接回传一帧。
    if n <= 1 {
        let _ = sink.add(pos);
        return Ok(());
    }

    let p = params.normalized();
    run_layout(n, &edges, &mut pos, &p, |frame| sink.add(frame).is_ok());
    Ok(())
}

/// 布局内核(生产与测试共用):播种帧 + 退火主循环,每帧调 `emit`(返回 false = 下游
/// 已取消,立即收尾)。返回实际执行的迭代数(早停时小于 `p.iterations`)。
fn run_layout(
    n: usize,
    edges: &[i32],
    pos: &mut [f32],
    p: &Params,
    mut emit: impl FnMut(Vec<f32>) -> bool,
) -> u32 {
    let masses = node_masses(n, edges);
    let mut vel = vec![0.0f32; n * 2];
    let mut force = vec![0.0f32; n * 2];
    let mut scratch = Scratch::new();

    // 归一化因子 =「相连中位距 / spring_length」的 EMA(逐帧原值会抖)。种子帧先按种子
    // 自身的尺度换算,免得第一帧与后续帧尺度跳变;关缩放时恒为 1.0,行为与旧版一致。
    let mut scale_ema = if p.normalize_scale {
        (layout_scale(pos, edges, n) / p.spring_length).clamp(1e-3, 1e6)
    } else {
        1.0
    };

    if !emit(scaled_frame(pos, scale_ema)) {
        return 0;
    }

    // d3-force 式退火:alpha 从 initial_alpha 几何衰减到 ALPHA_MIN(在末次迭代到达),力按
    // alpha 缩放、速度每步乘 velocity_retain。平衡点由力自身决定、与 alpha 无关,故只影响
    // 动态(平滑、无过冲),不改最终布局。这是消除「抽搐」的关键。
    let alpha_decay = 1.0 - ALPHA_MIN.powf(1.0 / p.iterations as f32);
    let mut alpha = p.initial_alpha;
    let mut still = 0u32;

    for iter in 0..p.iterations {
        let moved = integrate_step(
            &mut Bodies { pos: &mut *pos, vel: &mut vel, force: &mut force },
            edges,
            &masses,
            p,
            alpha,
            scale_ema,
            &mut scratch,
        );
        alpha *= 1.0 - alpha_decay;
        if p.normalize_scale {
            let raw = layout_scale(pos, edges, n) / p.spring_length;
            scale_ema = (scale_ema * 0.9 + raw * 0.1).clamp(1e-3, 1e6);
        }

        // 阈值随仿真尺度放大:开归一化时仿真空间被撑大 scale_ema 倍,位移绝对值同比变大,
        // 不换算的话大图永远触不到早停。
        let settled = p.min_step > 0.0
            && alpha < STILL_ALPHA
            && moved < p.min_step * p.spring_length * scale_ema;
        still = if settled { still + 1 } else { 0 };

        // 早停也走 last 分支,保证最终态一定被补发一帧。
        let last = still >= STILL_STEPS || iter + 1 == p.iterations;
        if last || iter % p.emit_every == 0 {
            // emit 报错 = 下游已取消订阅,提前收尾。
            if !emit(scaled_frame(pos, scale_ema)) {
                return iter + 1;
            }
            if p.frame_delay_ms > 0 && !last {
                thread::sleep(Duration::from_millis(p.frame_delay_ms as u64));
            }
        }
        if last {
            return iter + 1;
        }
    }
    p.iterations
}

/// 发帧副本:除以归一化因子,把仿真尺度换算成「相连中位距 ≈ spring_length」的视图。
fn scaled_frame(pos: &[f32], scale: f32) -> Vec<f32> {
    if scale == 1.0 {
        pos.to_vec()
    } else {
        pos.iter().map(|v| v / scale).collect()
    }
}

/// 当前布局的特征尺度:相连节点对欧氏距离的中位数;无边时退化为包围盒对角线 / (4·√n)。
fn layout_scale(pos: &[f32], edges: &[i32], n: usize) -> f32 {
    if n == 0 {
        return 1.0;
    }
    let mut dists: Vec<f32> = Vec::with_capacity(edges.len() / 2);
    let mut k = 0;
    while k + 1 < edges.len() {
        let a = edges[k] as usize;
        let b = edges[k + 1] as usize;
        k += 2;
        if a == b {
            continue;
        }
        let dx = pos[b * 2] - pos[a * 2];
        let dy = pos[b * 2 + 1] - pos[a * 2 + 1];
        dists.push((dx * dx + dy * dy).sqrt());
    }
    if dists.is_empty() {
        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;
        for i in 0..n {
            min_x = min_x.min(pos[i * 2]);
            max_x = max_x.max(pos[i * 2]);
            min_y = min_y.min(pos[i * 2 + 1]);
            max_y = max_y.max(pos[i * 2 + 1]);
        }
        let w = max_x - min_x;
        let h = max_y - min_y;
        let diag = (w * w + h * h).sqrt();
        return (diag / (4.0 * (n as f32).sqrt().max(1.0))).max(1e-6);
    }
    let mid = dists.len() / 2;
    let (_, m, _) = dists.select_nth_unstable_by(mid, f32::total_cmp);
    (*m).max(1e-6)
}

/// 黄金角螺旋播种:确定性、可复现、初始不重合。半径随节点数放大以留出铺展空间。
fn seed_positions(n: usize, initial: &[f32]) -> Result<Vec<f32>> {
    if !initial.is_empty() {
        if initial.len() != n * 2 {
            return Err(anyhow!(
                "initial_positions 长度应为 {} 实为 {}",
                n * 2,
                initial.len()
            ));
        }
        return Ok(initial.to_vec());
    }
    const GOLDEN_ANGLE: f32 = 2.399_963_2; // ~137.5°
    let scale = SEED_SPREAD * (n as f32).sqrt().max(1.0);
    let mut pos = vec![0.0f32; n * 2];
    for i in 0..n {
        let t = i as f32;
        let r = scale * (t / (n as f32).max(1.0)).sqrt();
        let a = t * GOLDEN_ANGLE;
        pos[i * 2] = r * a.cos();
        pos[i * 2 + 1] = r * a.sin();
    }
    Ok(pos)
}

/// FA2 质量 = 度数 + 1(度数按无向边表计)。
fn node_masses(n: usize, edges: &[i32]) -> Vec<f32> {
    let mut m = vec![1.0f32; n];
    let mut k = 0;
    while k + 1 < edges.len() {
        m[edges[k] as usize] += 1.0;
        m[edges[k + 1] as usize] += 1.0;
        k += 2;
    }
    m
}

/// FA2 线性引力:每条边 F = ka·d(无自然长),分量即位移差×ka——间距不是设出来的,
/// 而是与度数加权斥力平衡后涌现的:叶对距 = 2·√(kr/ka),度数越高的对自动越远。
fn accumulate_attraction(pos: &[f32], edges: &[i32], p: &Params, force: &mut [f32]) {
    let ka = p.spring_strength;
    let mut k = 0;
    while k + 1 < edges.len() {
        let a = edges[k] as usize;
        let b = edges[k + 1] as usize;
        k += 2;
        if a == b {
            continue;
        }
        let fx = (pos[b * 2] - pos[a * 2]) * ka;
        let fy = (pos[b * 2 + 1] - pos[a * 2 + 1]) * ka;
        force[a * 2] += fx;
        force[a * 2 + 1] += fy;
        force[b * 2] -= fx;
        force[b * 2 + 1] -= fy;
    }
}

fn accumulate_gravity(pos: &[f32], n: usize, p: &Params, force: &mut [f32]) {
    if p.gravity <= 0.0 {
        return;
    }
    for i in 0..n {
        force[i * 2] -= pos[i * 2] * p.gravity;
        force[i * 2 + 1] -= pos[i * 2 + 1] * p.gravity;
    }
}

/// 一步积分要更新的三组数组(打包传参)。
struct Bodies<'a> {
    pos: &'a mut [f32],
    vel: &'a mut [f32],
    force: &'a mut [f32],
}

/// 一步积分:清零并累加三种力,按 `alpha` 缩放施力、`velocity_retain` 衰减速度、`max_step`
/// 限位,原地更新 `pos`/`vel`。前 `pinned_count` 个节点只受力不动。`scale` 为当前归一化
/// 因子,碰撞半径与步长上限按它放大,使其在归一化视图里恒等于传入值。
/// 返回本步的最大节点位移(不含碰撞修正),供调用方判定收敛。
fn integrate_step(
    b: &mut Bodies<'_>,
    edges: &[i32],
    masses: &[f32],
    p: &Params,
    alpha: f32,
    scale: f32,
    scratch: &mut Scratch,
) -> f32 {
    let n = b.pos.len() / 2;
    for f in b.force.iter_mut() {
        *f = 0.0;
    }
    accumulate_repulsion(b.pos, masses, n, p, b.force, scratch);
    accumulate_attraction(b.pos, edges, p, b.force);
    accumulate_gravity(b.pos, n, p, b.force);

    // 每步位移设安全上限(约一个理想边长),防重合时的偶发爆炸。
    let max_step = p.spring_length * scale;
    let pinned = p.pinned_count.min(n);
    let mut max_disp = 0.0f32;
    for i in 0..n {
        let ix = i * 2;
        let iy = ix + 1;
        if i < pinned {
            b.vel[ix] = 0.0;
            b.vel[iy] = 0.0;
            continue;
        }
        let mut vx = b.vel[ix] * p.velocity_retain + b.force[ix] * alpha;
        let mut vy = b.vel[iy] * p.velocity_retain + b.force[iy] * alpha;
        let mut speed = (vx * vx + vy * vy).sqrt();
        if speed > max_step {
            let s = max_step / speed;
            vx *= s;
            vy *= s;
            speed = max_step;
        }
        b.vel[ix] = vx;
        b.vel[iy] = vy;
        b.pos[ix] += vx;
        b.pos[iy] += vy;
        max_disp = max_disp.max(speed);
    }
    resolve_collisions(b.pos, p.collide_radius * scale, pinned);
    max_disp
}

/// 碰撞解算(d3 forceCollide 的位置修正式):均匀网格哈希(格宽 = 直径)找近邻,
/// 圆心距 < 2r 的对推开重叠量。每步一遍,随迭代收敛到最小间距。O(N)。
/// 前 `pinned` 个节点不动:一对里只有一个被钉时重叠量全给未钉的那个,两个都钉则跳过。
fn resolve_collisions(pos: &mut [f32], r: f32, pinned: usize) {
    let n = pos.len() / 2;
    if r <= 0.0 || n < 2 {
        return;
    }
    let d = r * 2.0;
    let key = |x: f32, y: f32| ((x / d).floor() as i64, (y / d).floor() as i64);
    let mut grid: HashMap<(i64, i64), Vec<usize>> = HashMap::with_capacity(n);
    for i in 0..n {
        grid.entry(key(pos[i * 2], pos[i * 2 + 1])).or_default().push(i);
    }
    for i in 0..n {
        let (cx, cy) = key(pos[i * 2], pos[i * 2 + 1]);
        for gx in (cx - 1)..=(cx + 1) {
            for gy in (cy - 1)..=(cy + 1) {
                let Some(list) = grid.get(&(gx, gy)) else { continue };
                for &j in list {
                    if j <= i {
                        continue;
                    }
                    let (wi, wj) = match (i < pinned, j < pinned) {
                        (true, true) => continue,
                        (true, false) => (0.0, 1.0),
                        (false, true) => (1.0, 0.0),
                        (false, false) => (0.5, 0.5),
                    };
                    let dx = pos[j * 2] - pos[i * 2];
                    let dy = pos[j * 2 + 1] - pos[i * 2 + 1];
                    let dist_sq = dx * dx + dy * dy;
                    if dist_sq >= d * d {
                        continue;
                    }
                    if dist_sq <= f32::EPSILON {
                        // 完全重合:按下标黄金角确定性推开(无 RNG)。
                        let a = (i as f32) * 2.399_963_2;
                        let (s, c) = a.sin_cos();
                        pos[i * 2] -= c * r * wi;
                        pos[i * 2 + 1] -= s * r * wi;
                        pos[j * 2] += c * r * wj;
                        pos[j * 2 + 1] += s * r * wj;
                        continue;
                    }
                    let dist = dist_sq.sqrt();
                    let over = (d - dist) / dist;
                    pos[i * 2] -= dx * over * wi;
                    pos[i * 2 + 1] -= dy * over * wi;
                    pos[j * 2] += dx * over * wj;
                    pos[j * 2 + 1] += dy * over * wj;
                }
            }
        }
    }
}

// ---- Barnes-Hut 四叉树斥力 ----

/// 四叉树单元。用扁平 arena 存储,避免 Box 递归与借用麻烦。
struct Cell {
    cx: f32,
    cy: f32,
    half: f32,
    mass: f32,
    com_x: f32,
    com_y: f32,
    /// >=0 单体叶子;-1 表示内部节点或已细分。
    body: i32,
    /// 四象限子节点在 arena 的下标,-1 为空。
    children: [i32; 4],
    /// 是否已细分为内部节点。
    internal: bool,
}

impl Cell {
    fn empty(cx: f32, cy: f32, half: f32) -> Self {
        Cell {
            cx,
            cy,
            half,
            mass: 0.0,
            com_x: 0.0,
            com_y: 0.0,
            body: -1,
            children: [-1; 4],
            internal: false,
        }
    }
}

/// 跨迭代复用的临时缓冲:四叉树 arena 与遍历栈。避免每节点每步一次堆分配。
struct Scratch {
    tree: QuadTree,
    stack: Vec<u32>,
}

impl Scratch {
    fn new() -> Self {
        Scratch { tree: QuadTree { cells: Vec::new() }, stack: Vec::new() }
    }
}

struct QuadTree {
    cells: Vec<Cell>,
}

impl QuadTree {
    /// 清空 arena 并重建根,容量留给下一轮复用。
    fn reset(&mut self, cx: f32, cy: f32, half: f32) {
        self.cells.clear();
        self.cells.push(Cell::empty(cx, cy, half));
    }

    fn quadrant(&self, cell: usize, x: f32, y: f32) -> usize {
        let c = &self.cells[cell];
        let east = (x >= c.cx) as usize;
        let south = (y >= c.cy) as usize;
        south * 2 + east
    }

    fn child_cell(&mut self, cell: usize, q: usize) -> usize {
        if self.cells[cell].children[q] >= 0 {
            return self.cells[cell].children[q] as usize;
        }
        let (cx, cy, half) = {
            let c = &self.cells[cell];
            let h = c.half * 0.5;
            let east = (q & 1) == 1;
            let south = (q & 2) == 2;
            let nx = if east { c.cx + h } else { c.cx - h };
            let ny = if south { c.cy + h } else { c.cy - h };
            (nx, ny, h)
        };
        let idx = self.cells.len();
        self.cells.push(Cell::empty(cx, cy, half));
        self.cells[cell].children[q] = idx as i32;
        idx
    }
}

fn accumulate_repulsion(
    pos: &[f32],
    masses: &[f32],
    n: usize,
    p: &Params,
    force: &mut [f32],
    scratch: &mut Scratch,
) {
    // 计算包围盒。
    let mut min_x = f32::MAX;
    let mut min_y = f32::MAX;
    let mut max_x = f32::MIN;
    let mut max_y = f32::MIN;
    for i in 0..n {
        min_x = min_x.min(pos[i * 2]);
        max_x = max_x.max(pos[i * 2]);
        min_y = min_y.min(pos[i * 2 + 1]);
        max_y = max_y.max(pos[i * 2 + 1]);
    }
    let cx = (min_x + max_x) * 0.5;
    let cy = (min_y + max_y) * 0.5;
    let half = ((max_x - min_x).max(max_y - min_y) * 0.5).max(1.0) + 1.0;

    scratch.tree.reset(cx, cy, half);
    for i in 0..n {
        scratch
            .tree
            .insert_body(i, pos[i * 2], pos[i * 2 + 1], masses[i], pos, masses);
    }

    for i in 0..n {
        let (fx, fy) = scratch.tree.repulsion_on(
            pos[i * 2],
            pos[i * 2 + 1],
            masses[i],
            p,
            &mut scratch.stack,
        );
        force[i * 2] += fx;
        force[i * 2 + 1] += fy;
    }
}

impl QuadTree {
    /// 插入一个体(带 FA2 质量);遇到已占用的叶子时正确地把「老体」一起下推。
    fn insert_body(&mut self, body: usize, x: f32, y: f32, mass: f32, pos: &[f32], masses: &[f32]) {
        let mut cell = 0usize;
        let mut depth = 0u32;
        loop {
            let c = &mut self.cells[cell];
            let m = c.mass + mass;
            c.com_x = (c.com_x * c.mass + x * mass) / m;
            c.com_y = (c.com_y * c.mass + y * mass) / m;
            c.mass = m;

            if c.internal {
                let q = self.quadrant(cell, x, y);
                cell = self.child_cell(cell, q);
                depth += 1;
                continue;
            }

            if c.body < 0 {
                c.body = body as i32;
                return;
            }

            // 叶子已有老体:超深度则叠加为聚簇(质量已加),否则细分下推。
            if depth >= MAX_DEPTH {
                return;
            }
            let old = c.body as usize;
            let ox = pos[old * 2];
            let oy = pos[old * 2 + 1];
            self.cells[cell].internal = true;
            self.cells[cell].body = -1;

            // 老体下沉一层(其质量已计入本 cell,子层重新累计)。
            let oq = self.quadrant(cell, ox, oy);
            let ochild = self.child_cell(cell, oq);
            self.push_leaf(ochild, old, ox, oy, masses[old]);

            // 当前体继续从本 cell 下沉。
            let q = self.quadrant(cell, x, y);
            cell = self.child_cell(cell, q);
            depth += 1;
        }
    }

    /// 把一个体直接放进(空)子叶子并累计其质心。
    fn push_leaf(&mut self, cell: usize, body: usize, x: f32, y: f32, mass: f32) {
        let c = &mut self.cells[cell];
        let m = c.mass + mass;
        c.com_x = (c.com_x * c.mass + x * mass) / m;
        c.com_y = (c.com_y * c.mass + y * mass) / m;
        c.mass = m;
        c.body = body as i32;
    }

    /// 对质量 own_mass、位于 (x,y) 的体,遍历树累加 FA2 度数加权斥力。显式栈避免递归。
    fn repulsion_on(
        &self,
        x: f32,
        y: f32,
        own_mass: f32,
        p: &Params,
        stack: &mut Vec<u32>,
    ) -> (f32, f32) {
        let mut fx = 0.0f32;
        let mut fy = 0.0f32;
        stack.clear();
        stack.push(0);
        while let Some(idx) = stack.pop() {
            let c = &self.cells[idx as usize];
            if c.mass == 0.0 {
                continue;
            }
            let dx = x - c.com_x;
            let dy = y - c.com_y;
            let dist_sq = dx * dx + dy * dy + SOFTENING;

            let width = c.half * 2.0;
            // 叶子(单体或聚簇)或满足开角判据:整体当一个质点。
            if !c.internal || (width * width) < p.theta_sq * dist_sq {
                // FA2 斥力 F = kr·m_i·m_cell/d,沿连线方向 → 分量 = Δ·F/d = Δ·kr·m/d²。
                // 自身与自身不施力(dist≈0 时 Δ=0,软化项兜底)。
                let f = p.repulsion * own_mass * c.mass / dist_sq;
                fx += dx * f;
                fy += dy * f;
                continue;
            }
            for q in 0..4 {
                let ch = c.children[q];
                if ch >= 0 {
                    stack.push(ch as u32);
                }
            }
        }
        (fx, fy)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SL: f32 = 60.0;

    fn linked_dists(pos: &[f32], edges: &[i32]) -> Vec<f32> {
        let mut out = Vec::new();
        let mut k = 0;
        while k + 1 < edges.len() {
            let a = edges[k] as usize;
            let b = edges[k + 1] as usize;
            k += 2;
            let dx = pos[b * 2] - pos[a * 2];
            let dy = pos[b * 2 + 1] - pos[a * 2 + 1];
            out.push((dx * dx + dy * dy).sqrt());
        }
        out
    }

    fn median(v: &[f32]) -> f32 {
        let mut s = v.to_vec();
        s.sort_by(f32::total_cmp);
        s[s.len() / 2]
    }

    /// FA2:kr = ka·(SL/2)²,叶对(度数 1)平衡距即 SL。
    fn base_params(iters: u32) -> GraphLayoutParams {
        GraphLayoutParams {
            iterations: iters,
            theta: 0.9,
            repulsion: 0.08 * (SL / 2.0) * (SL / 2.0),
            spring_length: SL,
            spring_strength: 0.08,
            gravity: 0.02,
            collide_radius: 12.0,
            velocity_decay: 0.4,
            emit_every: 1,
            frame_delay_ms: 0,
            initial_alpha: 1.0,
            min_step: 0.0,
            pinned_count: 0,
            normalize_scale: false,
        }
    }

    /// 直接驱动内核(不经 StreamSink),返回(最后一帧发出的坐标, 实际迭代数)。
    fn drive(params: GraphLayoutParams, n: u32, edges: &[i32], initial: &[f32]) -> (Vec<f32>, u32) {
        let p = params.normalized();
        let mut pos = seed_positions(n as usize, initial).unwrap();
        let mut last = Vec::new();
        let iters = run_layout(n as usize, edges, &mut pos, &p, |f| {
            last = f;
            true
        });
        (last, iters)
    }

    fn run(n: u32, edges: Vec<i32>, iters: u32) -> Vec<f32> {
        drive(base_params(iters), n, &edges, &[]).0
    }

    /// 60 节点的链 + 星混合图(单连通分量)。
    fn mixed_graph() -> Vec<i32> {
        let mut edges: Vec<i32> = (0..29).flat_map(|i| [i, i + 1]).collect();
        edges.extend([29, 30]);
        for i in 31..60 {
            edges.extend([30, i]);
        }
        edges
    }

    #[test]
    fn positions_finite() {
        let pos = run(50, (0..49).flat_map(|i| [i, i + 1]).collect(), 200);
        assert_eq!(pos.len(), 100);
        assert!(pos.iter().all(|v| v.is_finite()));
    }

    #[test]
    fn fa2_linked_pairs_settle_near_equilibrium() {
        // 一条链:两体平衡距 = (SL/2)·√(m₁·m₂)(链中对 1.5·SL),但 FA2 斥力 1/d 是
        // 长程力,全链累计推挤会把链再拉伸约一倍(实测 ~3·SL)——间距由全局平衡涌现。
        // 断言相连对落入 [0.5, 4]·SL:收敛且未塌缩/未飞散。
        let edges: Vec<i32> = (0..19).flat_map(|i| [i, i + 1]).collect();
        let end = run(20, edges.clone(), 400);
        let dists = linked_dists(&end, &edges);
        for (i, d) in dists.iter().enumerate() {
            assert!(
                *d > SL * 0.5 && *d < SL * 4.0,
                "linked pair {i} dist {d} outside [{}, {}]",
                SL * 0.5,
                SL * 4.0,
            );
        }
    }

    #[test]
    fn empty_and_single_do_not_panic() {
        assert_eq!(seed_positions(0, &[]).unwrap().len(), 0);
        assert_eq!(seed_positions(1, &[]).unwrap().len(), 2);
        let _ = run(2, vec![0, 1], 50);
    }

    #[test]
    fn collision_enforces_min_distance() {
        // 星型:30 个叶子全连中心,叶子间相互挤压,碰撞应保证最小圆心距≈2r。
        let n = 31;
        let edges: Vec<i32> = (1..n).flat_map(|i| [0, i]).collect();
        let pos = run(n as u32, edges, 400);
        let r = 12.0_f32;
        let mut min_d = f32::MAX;
        for i in 0..n as usize {
            for j in (i + 1)..n as usize {
                let dx = pos[j * 2] - pos[i * 2];
                let dy = pos[j * 2 + 1] - pos[i * 2 + 1];
                min_d = min_d.min((dx * dx + dy * dy).sqrt());
            }
        }
        assert!(min_d >= 2.0 * r * 0.8, "min pairwise dist {min_d} < {}", 2.0 * r * 0.8);
    }

    #[test]
    fn normalization_pins_median_edge_length() {
        let edges = mixed_graph();

        // 不归一化:仿真空间的中位边长远大于 spring_length,正是大图「缩到看不见」的根因。
        let plain = drive(base_params(600), 60, &edges, &[]).0;
        let raw = median(&linked_dists(&plain, &edges)) / SL;
        assert!(raw > 2.0, "raw median ratio {raw} should be far above 1");

        let mut params = base_params(600);
        params.normalize_scale = true;
        let normed = drive(params, 60, &edges, &[]).0;
        let ratio = median(&linked_dists(&normed, &edges)) / SL;
        assert!(
            (0.6..=1.6).contains(&ratio),
            "normalized median ratio {ratio} outside [0.6, 1.6]"
        );
    }

    #[test]
    fn pinned_nodes_do_not_move() {
        let n = 40usize;
        let edges: Vec<i32> = (1..n as i32).flat_map(|i| [0, i]).collect();
        // 中心给一个偏离原点的种子:不钉的话会被向心力/斥力推走。
        let mut initial = seed_positions(n, &[]).unwrap();
        initial[0] = 17.5;
        initial[1] = -3.25;

        let mut params = base_params(200);
        params.pinned_count = 1;
        let p = params.normalized();
        let mut pos = initial.clone();
        run_layout(n, &edges, &mut pos, &p, |_| true);

        assert_eq!(pos[0], initial[0]);
        assert_eq!(pos[1], initial[1]);
    }

    #[test]
    fn early_exit_stops_before_max_iterations() {
        let edges: Vec<i32> = (0..7).flat_map(|i| [i, i + 1]).collect();
        let mut params = base_params(1000);
        params.min_step = 1e-3;
        let (_, iters) = drive(params, 8, &edges, &[]);
        assert!(iters < 1000, "expected early exit, ran {iters} iterations");
    }
}
