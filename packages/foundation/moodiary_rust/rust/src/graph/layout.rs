use anyhow::{Result, anyhow};
use std::collections::HashMap;
use std::thread;
use std::time::Duration;

pub struct GraphLayoutParams {
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

struct Params {
    iterations: u32,
    theta_sq: f32,
    repulsion: f32,
    spring_length: f32,
    spring_strength: f32,
    gravity: f32,
    collide_radius: f32,
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
            iterations: if self.iterations > 0 {
                self.iterations
            } else {
                400
            },
            theta_sq: theta * theta,
            repulsion: pos(self.repulsion, 72.0),
            spring_length: pos(self.spring_length, 60.0),
            spring_strength: pos(self.spring_strength, 0.08),
            gravity: if self.gravity >= 0.0 {
                self.gravity
            } else {
                0.02
            },
            collide_radius: pos(self.collide_radius, 12.0),
            velocity_retain: 1.0 - decay,
            emit_every: if self.emit_every > 0 {
                self.emit_every
            } else {
                1
            },
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

const SOFTENING: f32 = 0.01;
const MAX_DEPTH: u32 = 24;
const ALPHA_MIN: f32 = 0.001;
const SEED_SPREAD: f32 = 20.0;
const STILL_STEPS: u32 = 5;
const STILL_ALPHA: f32 = 0.05;

pub fn layout_graph_stream(
    node_count: u32,
    edges: Vec<i32>,
    initial_positions: Vec<f32>,
    params: GraphLayoutParams,
    mut emit: impl FnMut(Vec<f32>) -> bool,
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

    if n <= 1 {
        emit(pos);
        return Ok(());
    }

    let p = params.normalized();
    run_layout(n, &edges, &mut pos, &p, &mut emit);
    Ok(())
}

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

    let mut scale_ema = if p.normalize_scale {
        (layout_scale(pos, edges, n) / p.spring_length).clamp(1e-3, 1e6)
    } else {
        1.0
    };

    if !emit(scaled_frame(pos, scale_ema)) {
        return 0;
    }

    let alpha_decay = 1.0 - ALPHA_MIN.powf(1.0 / p.iterations as f32);
    let mut alpha = p.initial_alpha;
    let mut still = 0u32;

    for iter in 0..p.iterations {
        let moved = integrate_step(
            &mut Bodies {
                pos: &mut *pos,
                vel: &mut vel,
                force: &mut force,
            },
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

        let settled = p.min_step > 0.0
            && alpha < STILL_ALPHA
            && moved < p.min_step * p.spring_length * scale_ema;
        still = if settled { still + 1 } else { 0 };

        let last = still >= STILL_STEPS || iter + 1 == p.iterations;
        if last || iter % p.emit_every == 0 {
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

fn scaled_frame(pos: &[f32], scale: f32) -> Vec<f32> {
    if scale == 1.0 {
        pos.to_vec()
    } else {
        pos.iter().map(|v| v / scale).collect()
    }
}

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

struct Bodies<'a> {
    pos: &'a mut [f32],
    vel: &'a mut [f32],
    force: &'a mut [f32],
}

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

fn resolve_collisions(pos: &mut [f32], r: f32, pinned: usize) {
    let n = pos.len() / 2;
    if r <= 0.0 || n < 2 {
        return;
    }
    let d = r * 2.0;
    let key = |x: f32, y: f32| ((x / d).floor() as i64, (y / d).floor() as i64);
    let mut grid: HashMap<(i64, i64), Vec<usize>> = HashMap::with_capacity(n);
    for i in 0..n {
        grid.entry(key(pos[i * 2], pos[i * 2 + 1]))
            .or_default()
            .push(i);
    }
    for i in 0..n {
        let (cx, cy) = key(pos[i * 2], pos[i * 2 + 1]);
        for gx in (cx - 1)..=(cx + 1) {
            for gy in (cy - 1)..=(cy + 1) {
                let Some(list) = grid.get(&(gx, gy)) else {
                    continue;
                };
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

struct Cell {
    cx: f32,
    cy: f32,
    half: f32,
    mass: f32,
    com_x: f32,
    com_y: f32,
    body: i32,
    children: [i32; 4],
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

struct Scratch {
    tree: QuadTree,
    stack: Vec<u32>,
}

impl Scratch {
    fn new() -> Self {
        Scratch {
            tree: QuadTree { cells: Vec::new() },
            stack: Vec::new(),
        }
    }
}

struct QuadTree {
    cells: Vec<Cell>,
}

impl QuadTree {
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
        let (fx, fy) =
            scratch
                .tree
                .repulsion_on(pos[i * 2], pos[i * 2 + 1], masses[i], p, &mut scratch.stack);
        force[i * 2] += fx;
        force[i * 2 + 1] += fy;
    }
}

impl QuadTree {
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

            if depth >= MAX_DEPTH {
                return;
            }
            let old = c.body as usize;
            let ox = pos[old * 2];
            let oy = pos[old * 2 + 1];
            self.cells[cell].internal = true;
            self.cells[cell].body = -1;

            let oq = self.quadrant(cell, ox, oy);
            let ochild = self.child_cell(cell, oq);
            self.push_leaf(ochild, old, ox, oy, masses[old]);

            let q = self.quadrant(cell, x, y);
            cell = self.child_cell(cell, q);
            depth += 1;
        }
    }

    fn push_leaf(&mut self, cell: usize, body: usize, x: f32, y: f32, mass: f32) {
        let c = &mut self.cells[cell];
        let m = c.mass + mass;
        c.com_x = (c.com_x * c.mass + x * mass) / m;
        c.com_y = (c.com_y * c.mass + y * mass) / m;
        c.mass = m;
        c.body = body as i32;
    }

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
            if !c.internal || (width * width) < p.theta_sq * dist_sq {
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
        assert!(
            min_d >= 2.0 * r * 0.8,
            "min pairwise dist {min_d} < {}",
            2.0 * r * 0.8
        );
    }

    #[test]
    fn normalization_pins_median_edge_length() {
        let edges = mixed_graph();

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
