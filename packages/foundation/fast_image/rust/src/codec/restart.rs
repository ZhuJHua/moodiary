use std::sync::atomic::{AtomicUsize, Ordering};

use anyhow::{Result, anyhow, bail};
use memchr::memchr;

use crate::codec::region::Rect;
use crate::codec::turbo::{self, PixelRegion};

const MIN_ROWS_PER_CHUNK: u32 = 8;
const CHUNK_BYTES: usize = 8 * 1024 * 1024;
const MAX_THREADS: usize = 6;

pub struct RestartIndex {
    header: Vec<u8>,
    sof_height_at: usize,
    entropy_start: usize,
    entropy_end: usize,
    markers: Vec<usize>,
    mcu_height: u32,
    mcu_rows: u32,
    row_step: u32,
    intervals_per_row: u32,
    height: u32,
}

type Indexed = (usize, (u32, PixelRegion));

struct RowSlice {
    jpeg: Vec<u8>,
    start_row: u32,
}

impl RestartIndex {
    pub fn build(bytes: &[u8]) -> Option<RestartIndex> {
        if bytes.len() < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 {
            return None;
        }
        let mut header = vec![0xFF, 0xD8];
        let mut i = 2usize;
        let mut sof_height_at = None;
        let mut mcu_w = 0u32;
        let mut mcu_h = 0u32;
        let mut width = 0u32;
        let mut height = 0u32;
        let mut restart_interval = 0u32;
        let entropy_start;
        loop {
            if i + 4 > bytes.len() || bytes[i] != 0xFF {
                return None;
            }
            let marker = bytes[i + 1];
            if marker == 0xFF {
                i += 1;
                continue;
            }
            let len = u16::from_be_bytes([bytes[i + 2], bytes[i + 3]]) as usize;
            let seg = i + 2 + len;
            if len < 2 || seg > bytes.len() {
                return None;
            }
            let mut keep = true;
            match marker {
                0xC0 | 0xC1 => {
                    if len < 8 || bytes[i + 4] != 8 {
                        return None;
                    }
                    sof_height_at = Some(header.len() + 5);
                    height = u16::from_be_bytes([bytes[i + 5], bytes[i + 6]]) as u32;
                    width = u16::from_be_bytes([bytes[i + 7], bytes[i + 8]]) as u32;
                    let ncomp = bytes[i + 9] as usize;
                    let (mut hmax, mut vmax) = (1u32, 1u32);
                    for c in 0..ncomp {
                        let hv = *bytes.get(i + 11 + c * 3)?;
                        hmax = hmax.max((hv >> 4) as u32);
                        vmax = vmax.max((hv & 0x0F) as u32);
                    }
                    mcu_w = 8 * hmax;
                    mcu_h = 8 * vmax;
                }
                0xC2 | 0xC3 | 0xC5..=0xC7 | 0xC9..=0xCB | 0xCD..=0xCF => return None,
                0xDD => {
                    if len != 4 {
                        return None;
                    }
                    restart_interval = u16::from_be_bytes([bytes[i + 4], bytes[i + 5]]) as u32;
                }
                0xDA => {
                    header.extend_from_slice(&bytes[i..seg]);
                    entropy_start = seg;
                    break;
                }
                0xE0..=0xED | 0xEF | 0xFE => keep = false,
                _ => {}
            }
            if keep {
                header.extend_from_slice(&bytes[i..seg]);
            }
            i = seg;
        }
        let sof_height_at = sof_height_at?;
        if restart_interval == 0 || width == 0 || height == 0 || mcu_w == 0 {
            return None;
        }
        let mcus_per_row = width.div_ceil(mcu_w);
        let mcu_rows = height.div_ceil(mcu_h);
        let (row_step, intervals_per_row) = if restart_interval.is_multiple_of(mcus_per_row) {
            (restart_interval / mcus_per_row, 1)
        } else if mcus_per_row.is_multiple_of(restart_interval) {
            (1, mcus_per_row / restart_interval)
        } else {
            return None;
        };

        let mut markers = Vec::new();
        let mut pos = entropy_start;
        let entropy_end;
        loop {
            let at = pos + memchr(0xFF, &bytes[pos..])?;
            let next = *bytes.get(at + 1)?;
            match next {
                0x00 => {}
                0xFF => {
                    pos = at + 1;
                    continue;
                }
                0xD0..=0xD7 => markers.push(at),
                0xD9 => {
                    entropy_end = at;
                    break;
                }
                _ => return None,
            }
            pos = at + 2;
        }
        let mcus = mcus_per_row as u64 * mcu_rows as u64;
        let expected = mcus.div_ceil(restart_interval as u64).saturating_sub(1);
        if markers.len() as u64 != expected {
            return None;
        }

        Some(RestartIndex {
            header,
            sof_height_at,
            entropy_start,
            entropy_end,
            markers,
            mcu_height: mcu_h,
            mcu_rows,
            row_step,
            intervals_per_row,
            height,
        })
    }

    fn interval_at(&self, row: u32) -> usize {
        (row / self.row_step * self.intervals_per_row) as usize
    }

    fn bytes_of_rows(&self, row0: u32, row1: u32) -> usize {
        let to = if row1 >= self.mcu_rows {
            self.entropy_end
        } else {
            self.interval_offset(self.interval_at(row1))
        };
        to.saturating_sub(self.interval_offset(self.interval_at(row0)))
    }

    fn interval_offset(&self, i: usize) -> usize {
        if i == 0 {
            self.entropy_start
        } else {
            self.markers[i - 1] + 2
        }
    }

    fn slice_rows(&self, bytes: &[u8], row0: u32, row1: u32) -> Result<RowSlice> {
        let row1 = row1.min(self.mcu_rows);
        if row0 >= row1 || !row0.is_multiple_of(self.row_step) {
            bail!("bad restart slice rows {row0}..{row1}");
        }
        let start = self.interval_at(row0);
        let from = self.interval_offset(start);
        let to = if row1 >= self.mcu_rows {
            self.entropy_end
        } else {
            if !row1.is_multiple_of(self.row_step) {
                bail!("restart slice end {row1} is not aligned");
            }
            self.markers[self.interval_at(row1) - 1]
        };
        let pixel_height =
            ((row1 - row0) * self.mcu_height).min(self.height - row0 * self.mcu_height);

        let mut jpeg = Vec::with_capacity(self.header.len() + (to - from) + 2);
        jpeg.extend_from_slice(&self.header);
        let h = (pixel_height as u16).to_be_bytes();
        jpeg[self.sof_height_at] = h[0];
        jpeg[self.sof_height_at + 1] = h[1];
        let body_at = jpeg.len();
        jpeg.extend_from_slice(&bytes[from..to]);
        let mut n = 0u8;
        let mut pos = body_at;
        while let Some(off) = memchr(0xFF, &jpeg[pos..]) {
            let at = pos + off;
            if at + 1 >= jpeg.len() {
                break;
            }
            match jpeg[at + 1] {
                0xFF => {
                    pos = at + 1;
                    continue;
                }
                0xD0..=0xD7 => {
                    jpeg[at + 1] = 0xD0 + n;
                    n = (n + 1) % 8;
                }
                _ => {}
            }
            pos = at + 2;
        }
        jpeg.extend_from_slice(&[0xFF, 0xD9]);
        Ok(RowSlice {
            jpeg,
            start_row: row0,
        })
    }

    pub fn decode(
        &self,
        bytes: &[u8],
        num: u8,
        rect: Rect,
        rgba: bool,
        threads: usize,
    ) -> Result<PixelRegion> {
        let num = num.clamp(1, 8);
        let rows_per_mcu = self.mcu_height * num as u32 / 8;
        let scaled_h = turbo::scaled(self.height, num);
        let y0 = rect.y.min(scaled_h);
        let y1 = (rect.y + rect.h).min(scaled_h);
        if y1 <= y0 {
            bail!("empty region");
        }
        let step = self.row_step;
        let r0 = (y0 / rows_per_mcu) / step * step;
        let r1 = y1.div_ceil(rows_per_mcu).min(self.mcu_rows);
        let span = r1 - r0;

        let threads = threads.clamp(1, MAX_THREADS);
        let by_rows = (span / MIN_ROWS_PER_CHUNK.max(step)) as usize;
        let by_bytes = self.bytes_of_rows(r0, r1).div_ceil(CHUNK_BYTES);
        let chunks = by_rows
            .min(threads)
            .max(by_bytes)
            .clamp(1, (span / step).max(1) as usize);
        let mut bounds: Vec<u32> = (0..chunks)
            .map(|i| r0 + (span as u64 * i as u64 / chunks as u64) as u32 / step * step)
            .collect();
        bounds.push(r1);
        bounds.dedup();
        let jobs: Vec<(u32, u32)> = bounds.windows(2).map(|w| (w[0], w[1])).collect();

        let run = |(a, b): (u32, u32)| -> Result<(u32, PixelRegion)> {
            let top = a.saturating_sub(step);
            let bottom = ((b + step).div_ceil(step) * step).min(self.mcu_rows);
            let slice = self.slice_rows(bytes, top, bottom)?;
            let origin = slice.start_row * rows_per_mcu;
            let local_y0 = y0.max(a * rows_per_mcu) - origin;
            let local_y1 = y1.min(b * rows_per_mcu) - origin;
            let region = turbo::decode_region_n8(
                &slice.jpeg,
                num,
                Rect {
                    x: rect.x,
                    y: local_y0,
                    w: rect.w,
                    h: local_y1 - local_y0,
                },
                rgba,
            )?;
            Ok((origin, region))
        };

        let parts: Vec<(u32, PixelRegion)> = if jobs.len() == 1 {
            vec![run(jobs[0])?]
        } else {
            let next = AtomicUsize::new(0);
            let workers = threads.min(jobs.len());
            let collected: Vec<Result<Vec<Indexed>>> = std::thread::scope(|scope| {
                let handles: Vec<_> = (0..workers)
                    .map(|_| {
                        scope.spawn(|| {
                            let mut done = Vec::new();
                            loop {
                                let i = next.fetch_add(1, Ordering::Relaxed);
                                let Some(&job) = jobs.get(i) else {
                                    break;
                                };
                                done.push((i, run(job)?));
                            }
                            Ok(done)
                        })
                    })
                    .collect();
                handles
                    .into_iter()
                    .map(|h| h.join().map_err(|_| anyhow!("decode thread panicked"))?)
                    .collect()
            });
            let mut indexed: Vec<Indexed> = Vec::with_capacity(jobs.len());
            for batch in collected {
                indexed.extend(batch?);
            }
            indexed.sort_by_key(|(i, _)| *i);
            indexed.into_iter().map(|(_, p)| p).collect()
        };

        let (first_origin, first) = parts.first().ok_or_else(|| anyhow!("no chunks"))?;
        let (x, width, channels) = (first.x, first.width, first.channels);
        let y = first_origin + first.y;
        if parts.len() == 1 {
            let (_, region) = parts.into_iter().next().unwrap();
            return Ok(PixelRegion { y, ..region });
        }
        let height: u32 = parts.iter().map(|(_, r)| r.height).sum();
        let stride = width as usize * channels as usize;
        let mut pixels = Vec::with_capacity(stride * height as usize);
        let mut next_y = y;
        for (origin, region) in &parts {
            if region.x != x || region.width != width || origin + region.y != next_y {
                bail!("restart chunks do not line up");
            }
            pixels.extend_from_slice(&region.pixels);
            next_y += region.height;
        }
        Ok(PixelRegion {
            x,
            y,
            width,
            height,
            channels,
            pixels,
        })
    }
}

pub fn threads() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1)
        .clamp(1, MAX_THREADS)
}

#[cfg(test)]
mod tests {
    use super::RestartIndex;
    use crate::codec::region::Rect;
    use crate::codec::turbo;

    fn noisy(width: u32, height: u32) -> Vec<u8> {
        let mut seed = 0x9E37_79B9u32;
        let mut rgb = Vec::with_capacity((width * height * 3) as usize);
        for y in 0..height {
            for x in 0..width {
                seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
                let n = (seed >> 24) as u8;
                rgb.push(((x * 255 / width) as u8).wrapping_add(n / 4));
                rgb.push(((y * 255 / height) as u8).wrapping_add(n / 3));
                rgb.push(n);
            }
        }
        rgb
    }

    fn jpeg(width: u32, height: u32, chroma_444: bool, restart_rows: u16) -> Vec<u8> {
        turbo::encode_jpeg_with(
            &noisy(width, height),
            width,
            height,
            90,
            chroma_444,
            restart_rows,
            false,
        )
        .unwrap()
    }

    #[test]
    fn index_needs_aligned_restart_markers() {
        assert!(RestartIndex::build(&jpeg(1000, 700, false, 0)).is_none());
        let one = RestartIndex::build(&jpeg(1000, 700, false, 1)).unwrap();
        assert_eq!((one.row_step, one.intervals_per_row), (1, 1));
        assert_eq!(one.mcu_rows, 44);
        assert_eq!(one.markers.len(), 43);
        let three = RestartIndex::build(&jpeg(1000, 700, false, 3)).unwrap();
        assert_eq!(three.row_step, 3);
        assert_eq!(three.markers.len(), 14);
        let mut prog = Vec::new();
        let img = image::RgbImage::from_raw(64, 64, noisy(64, 64)).unwrap();
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut prog, 80)
            .encode_image(&img)
            .unwrap();
        assert!(RestartIndex::build(&prog).is_none(), "无 DRI 的也不接");
    }

    #[test]
    fn chunked_decode_matches_full_decode() {
        for (chroma_444, restart_rows) in [(false, 1), (false, 3), (true, 1), (true, 5)] {
            let bytes = jpeg(1000, 700, chroma_444, restart_rows);
            let index = RestartIndex::build(&bytes).unwrap();
            for num in [8u8, 4, 3, 2, 1] {
                let w = turbo::scaled(1000, num);
                let h = turbo::scaled(700, num);
                let rects = [
                    Rect { x: 0, y: 0, w, h },
                    Rect {
                        x: 0,
                        y: 0,
                        w: w / 3,
                        h: h / 5,
                    },
                    Rect {
                        x: 37 * num as u32 / 8,
                        y: 53 * num as u32 / 8,
                        w: w / 2,
                        h: h / 2,
                    },
                    Rect {
                        x: w - 9,
                        y: h - 7,
                        w: 9,
                        h: 7,
                    },
                    Rect {
                        x: 0,
                        y: h / 2,
                        w,
                        h: 1,
                    },
                ];
                for rect in rects {
                    let want = turbo::decode_region_n8(&bytes, num, rect, true).unwrap();
                    let got = index.decode(&bytes, num, rect, true, 3).unwrap();
                    assert_eq!(
                        (got.x, got.y, got.width, got.height),
                        (want.x, want.y, want.width, want.height),
                        "444={chroma_444} rows={restart_rows} num={num} {rect:?}"
                    );
                    assert!(
                        got.pixels == want.pixels,
                        "444={chroma_444} rows={restart_rows} num={num} {rect:?}: 像素不一致"
                    );
                }
            }
        }
    }

    #[test]
    fn fill_bytes_before_markers_are_handled() {
        let bytes = jpeg(1000, 700, false, 1);
        let plain = RestartIndex::build(&bytes).unwrap();
        let mut padded = Vec::with_capacity(bytes.len() + 64);
        let mut i = 0;
        while i < bytes.len() {
            if bytes[i] == 0xFF && i + 1 < bytes.len() && (0xD0..=0xD7).contains(&bytes[i + 1]) {
                padded.push(0xFF);
            }
            padded.push(bytes[i]);
            i += 1;
        }
        let index = RestartIndex::build(&padded).expect("填充字节不该让索引失败");
        assert_eq!(index.markers.len(), plain.markers.len());
        let rect = Rect {
            x: 40,
            y: 300,
            w: 500,
            h: 200,
        };
        let want = turbo::decode_region_n8(&padded, 8, rect, true).unwrap();
        let got = index.decode(&padded, 8, rect, true, 3).unwrap();
        assert!(got.pixels == want.pixels, "填充字节后分段解码应仍一致");
    }

    #[test]
    fn progressive_to_baseline_is_lossless_and_indexed() {
        let rgb = noisy(1000, 700);
        let prog = turbo::encode_jpeg_with(&rgb, 1000, 700, 88, false, 0, true).unwrap();
        assert!(turbo::read_header(&prog).unwrap().progressive);
        assert!(RestartIndex::build(&prog).is_none());
        let base = turbo::to_baseline(&prog, 1).unwrap();
        let header = turbo::read_header(&base).unwrap();
        assert!(!header.progressive && header.region_decodable());
        let index = RestartIndex::build(&base).unwrap();
        assert_eq!(index.row_step, 1);
        for num in [8u8, 2] {
            let a = turbo::decode_scaled(&prog, num).unwrap();
            let b = turbo::decode_scaled(&base, num).unwrap();
            assert!(
                a.as_raw() == b.as_raw(),
                "num={num}: 转码后像素应逐字节相同"
            );
        }
    }

    #[test]
    fn rgb_full_decode_matches_decode_scaled() {
        let bytes = jpeg(1000, 700, false, 2);
        let index = RestartIndex::build(&bytes).unwrap();
        for num in [8u8, 5, 1] {
            let want = turbo::decode_scaled(&bytes, num).unwrap();
            let got = index
                .decode(
                    &bytes,
                    num,
                    Rect {
                        x: 0,
                        y: 0,
                        w: turbo::scaled(1000, num),
                        h: turbo::scaled(700, num),
                    },
                    false,
                    4,
                )
                .unwrap();
            assert_eq!(
                (got.width, got.height, got.channels),
                (want.width(), want.height(), 3)
            );
            assert!(got.pixels == want.as_raw()[..], "num={num}");
        }
    }
}

#[cfg(test)]
mod bench {
    use std::time::Instant;

    use super::RestartIndex;
    use crate::codec::region::Rect;
    use crate::codec::turbo;

    #[test]
    #[ignore]
    fn env_file() {
        let Ok(path) = std::env::var("MOODIARY_BENCH_JPEG") else {
            return;
        };
        let bytes = std::fs::read(&path).unwrap();
        let header = turbo::read_header(&bytes).unwrap();
        let t = Instant::now();
        let index = RestartIndex::build(&bytes);
        println!(
            "{}x{} {}MB: index {:?} in {:?}",
            header.width,
            header.height,
            bytes.len() >> 20,
            index.as_ref().map(|i| (i.row_step, i.markers.len())),
            t.elapsed()
        );
        let Some(index) = index else {
            return;
        };
        let full = Rect {
            x: 0,
            y: 0,
            w: turbo::scaled(header.width, 1),
            h: turbo::scaled(header.height, 1),
        };
        let t = Instant::now();
        turbo::decode_region_n8(&bytes, 1, full, true).unwrap();
        println!("fit 1/8 whole, plain:    {:?}", t.elapsed());
        for threads in [1, 2, 4, 6] {
            let t = Instant::now();
            index.decode(&bytes, 1, full, true, threads).unwrap();
            println!("fit 1/8 whole, {threads} threads: {:?}", t.elapsed());
        }
        let band = Rect {
            x: 0,
            y: header.height / 2,
            w: header.width,
            h: 512,
        };
        let t = Instant::now();
        turbo::decode_region_n8(&bytes, 8, band, true).unwrap();
        println!("1/1 mid band 512 rows, plain: {:?}", t.elapsed());
        for threads in [1, 4] {
            let t = Instant::now();
            index.decode(&bytes, 8, band, true, threads).unwrap();
            println!(
                "1/1 mid band 512 rows, {threads} threads: {:?}",
                t.elapsed()
            );
        }
    }
}
