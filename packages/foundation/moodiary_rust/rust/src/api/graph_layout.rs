//! 知识图谱的力导向布局:**ForceAtlas2 力模型**(Jacomy 2014,Gephi 默认)+ Barnes-Hut
//! 四叉树加速(O(N log N))。斥力按度数加权(`kr·(deg₁+1)(deg₂+1)/d`,hub 周围自动更疏),
//! 边上为线性引力(无自然长,间距由力平衡涌现);两处刻意偏离原版:保留线性向心力(把
//! 不连通分量收进视野)与 forceCollide 碰撞(硬保不重叠)。积分器为 d3 式平滑退火。
//! 中间坐标经 [StreamSink] 逐帧回传;下游取消(离页/换筛选)时 `sink.add` 报错,循环即止。

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
        }
    }
}

/// 距离过近时的软化项,避免斥力爆炸/除零。
const SOFTENING: f32 = 0.01;
/// 四叉树最大深度;坐标重合时防止无限细分。
const MAX_DEPTH: u32 = 48;
/// 退火终点(d3 alphaMin 惯例值):alpha 几何衰减,恰在末次迭代降到此值。
const ALPHA_MIN: f32 = 0.001;
/// 播种螺旋的铺展基准(世界单位):半径随 √N 放大。
const SEED_SPREAD: f32 = 20.0;

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
    if edges.len() % 2 != 0 {
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
    let masses = node_masses(n, &edges);
    let mut vel = vec![0.0f32; n * 2];
    let mut force = vec![0.0f32; n * 2];

    // 先发一帧种子(散开的初态),动画从这里开始沉降。
    if sink.add(pos.clone()).is_err() {
        return Ok(());
    }

    // d3-force 式退火:alpha 从 1 几何衰减到 ALPHA_MIN(在末次迭代到达),力按 alpha
    // 缩放、速度每步乘 velocity_retain。平衡点由力自身决定、与 alpha 无关,故只影响动态
    // (平滑、无过冲),不改最终布局。这是消除「抽搐」的关键。
    let alpha_decay = 1.0 - ALPHA_MIN.powf(1.0 / p.iterations as f32);
    let mut alpha = 1.0_f32;

    for iter in 0..p.iterations {
        integrate_step(&mut pos, &mut vel, &mut force, &edges, &masses, &p, alpha);
        alpha *= 1.0 - alpha_decay;

        let last = iter + 1 == p.iterations;
        if last || iter % p.emit_every == 0 {
            // add 报错 = 下游已取消订阅,提前收尾。
            if sink.add(pos.clone()).is_err() {
                return Ok(());
            }
            if p.frame_delay_ms > 0 && !last {
                thread::sleep(Duration::from_millis(p.frame_delay_ms as u64));
            }
        }
    }

    Ok(())
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

/// 一步积分(生产循环与测试共用,消除拷贝漂移):清零并累加三种力,按 `alpha` 缩放施力、
/// `velocity_retain` 衰减速度、`max_step` 限位,原地更新 `pos`/`vel`。调用方管理 alpha 退火。
fn integrate_step(
    pos: &mut [f32],
    vel: &mut [f32],
    force: &mut [f32],
    edges: &[i32],
    masses: &[f32],
    p: &Params,
    alpha: f32,
) {
    let n = pos.len() / 2;
    for f in force.iter_mut() {
        *f = 0.0;
    }
    accumulate_repulsion(pos, masses, n, p, force);
    accumulate_attraction(pos, edges, p, force);
    accumulate_gravity(pos, n, p, force);

    // 每步位移设安全上限(约一个理想边长),防重合时的偶发爆炸。
    let max_step = p.spring_length;
    for i in 0..n {
        let ix = i * 2;
        let iy = ix + 1;
        let mut vx = vel[ix] * p.velocity_retain + force[ix] * alpha;
        let mut vy = vel[iy] * p.velocity_retain + force[iy] * alpha;
        let speed = (vx * vx + vy * vy).sqrt();
        if speed > max_step {
            let s = max_step / speed;
            vx *= s;
            vy *= s;
        }
        vel[ix] = vx;
        vel[iy] = vy;
        pos[ix] += vx;
        pos[iy] += vy;
    }
    resolve_collisions(pos, p.collide_radius);
}

/// 碰撞解算(d3 forceCollide 的位置修正式):均匀网格哈希(格宽 = 直径)找近邻,
/// 圆心距 < 2r 的对各推开一半重叠量。每步一遍,随迭代收敛到最小间距。O(N)。
fn resolve_collisions(pos: &mut [f32], r: f32) {
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
                        pos[i * 2] -= c * r * 0.5;
                        pos[i * 2 + 1] -= s * r * 0.5;
                        pos[j * 2] += c * r * 0.5;
                        pos[j * 2 + 1] += s * r * 0.5;
                        continue;
                    }
                    let dist = dist_sq.sqrt();
                    let push = (d - dist) * 0.5 / dist;
                    let px = dx * push;
                    let py = dy * push;
                    pos[i * 2] -= px;
                    pos[i * 2 + 1] -= py;
                    pos[j * 2] += px;
                    pos[j * 2 + 1] += py;
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

struct QuadTree {
    cells: Vec<Cell>,
}

impl QuadTree {
    fn new(cx: f32, cy: f32, half: f32) -> Self {
        QuadTree {
            cells: vec![Cell {
                cx,
                cy,
                half,
                mass: 0.0,
                com_x: 0.0,
                com_y: 0.0,
                body: -1,
                children: [-1; 4],
                internal: false,
            }],
        }
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
        self.cells.push(Cell {
            cx,
            cy,
            half,
            mass: 0.0,
            com_x: 0.0,
            com_y: 0.0,
            body: -1,
            children: [-1; 4],
            internal: false,
        });
        self.cells[cell].children[q] = idx as i32;
        idx
    }
}

fn accumulate_repulsion(pos: &[f32], masses: &[f32], n: usize, p: &Params, force: &mut [f32]) {
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

    let tree = build_tree(pos, masses, n, cx, cy, half);

    for i in 0..n {
        let (fx, fy) = tree.repulsion_on(pos[i * 2], pos[i * 2 + 1], masses[i], p);
        force[i * 2] += fx;
        force[i * 2 + 1] += fy;
    }
}

fn build_tree(pos: &[f32], masses: &[f32], n: usize, cx: f32, cy: f32, half: f32) -> QuadTree {
    let mut tree = QuadTree::new(cx, cy, half);
    for i in 0..n {
        tree.insert_body(i, pos[i * 2], pos[i * 2 + 1], masses[i], pos, masses);
    }
    tree
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
    fn repulsion_on(&self, x: f32, y: f32, own_mass: f32, p: &Params) -> (f32, f32) {
        let mut fx = 0.0f32;
        let mut fy = 0.0f32;
        let mut stack: Vec<usize> = Vec::with_capacity(64);
        stack.push(0);
        while let Some(idx) = stack.pop() {
            let c = &self.cells[idx];
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
                    stack.push(ch as usize);
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

    fn run(n: u32, edges: Vec<i32>, iters: u32) -> Vec<f32> {
        // 镜像 layout_graph_stream 的内核(不经 StreamSink):直接跑迭代拿末态。
        // FA2:kr = ka·(SL/2)²,叶对(度数 1)平衡距即 SL。
        let params = GraphLayoutParams {
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
        };
        let p = params.normalized();
        let mut pos = seed_positions(n as usize, &[]).unwrap();
        let nn = n as usize;
        let masses = node_masses(nn, &edges);
        let mut vel = vec![0.0f32; nn * 2];
        let mut force = vec![0.0f32; nn * 2];
        let alpha_decay = 1.0 - ALPHA_MIN.powf(1.0 / p.iterations as f32);
        let mut alpha = 1.0_f32;
        for _ in 0..p.iterations {
            integrate_step(&mut pos, &mut vel, &mut force, &edges, &masses, &p, alpha);
            alpha *= 1.0 - alpha_decay;
        }
        pos
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
}
