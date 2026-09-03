# 图片管线设计（原件不动、派生物承担浏览、看图页按需解原图）

> 2026-09-02 的图片重做（原字节直存 + 两档 WebP 缩略图 + `MediaImage`）之上，把 turbojpeg
> 引进来之后的整体架构。输入：今天两个 commit 的评审、`ImageDerivatives` 的第二轮策略拍板
> （展示端只查不生成）、超高分辨率看图页调研（Flutter 无区域解码、pixa 源码、turbojpeg-sys
> 1.2.0 = libjpeg-turbo 3.1.0 实包核查）。三条硬约束：**用户原图尽量一个字节不动**；两端
> （Flutter + webview）都解不了的格式才转码；**看图页与下载给的都是原图**。
>
> 2026-09-03：restart marker 随机访问 + 分段并行落地并真机验收；turbojpeg 缩放系数修正为
> N/8 十六档（原先 1/3、1/6 会被拒）。同日 tile 方案扩到 PNG、WebP 与 progressive JPEG
> （模拟器验收）。分期进度见 §5。

## 0. 结论先行

四层，每层只认自己的输入，原图只在两处被读：入库时读头、看图页放大时按区域解。

```
选图 / 粘贴 / 同步拉图 / 备份导入
        │  L0 入库：魔数定后缀、HEIC→JPG（唯一转码）、读头、预热派生物
        ▼
L1 原件 image/<uuid>.<ext>         ← 同步 / 备份 / 导出 / 分享 / 存相册 只认这一层
        │  L2 派生：image/thumb/<uuid>_{512,1280}.{jpg,png}（本机、不同步、可重算）
        ▼
L3 展示：列表 / 日历 / 媒体库 / 编辑器正文 → 只碰 L2
         看图页 → m 档打底 → 整图按屏缩放解 → 放大后按可见区域解（turbojpeg）
```

- **原件不动**：JPEG / PNG / WebP / GIF / BMP 原字节落盘。HEIC/HEIF 是唯一例外：iOS 的
  Flutter 与 Android 的 webview 都解不了，固定转 JPG。不转格式、不减像素、不烤 EXIF 方向。
- **浏览场景永远不解原图**：一屏十几格每格解一张 12MP 是过去卡顿与内存炸点的根子，
  现在列表只读 512 / 1280 的派生物，一张几十 KB、1–3ms。
- **看图页显示原图但从不整解原图**：m 档瞬时打底 → turbojpeg 按 fit 比例 N/8 缩放解出刚好
  够屏幕密度的一张 → 用户放大后 `tj3SetCroppingRegion` 只解可见区域。内存上界由视口决定，
  与图片分辨率无关，48MP 与 12MP 一个价。带 restart marker 的文件（相机、修图软件、libjpeg
  系导出的大多带）只熵解码覆盖视口的段并且并行；没有的整趟到底。
- **turbojpeg 进、libwebp 出**：turbojpeg-sys（vendored libjpeg-turbo 3.1.0，静态链进现有
  那一个 .so）负责 JPEG 的读头、缩放解码、区域解码与**派生物编码**；`image` 留着解非 JPEG；
  `webp` crate 摘掉。派生物改 JPEG（带 alpha 的源用 PNG），一张照片的生成从约 75ms 降到
  约 20ms，.so 实测 +1.06MB（含 rayon，减 libwebp）。
- **派生物可丢**：`image/thumb/` 在 support 目录但不同步、不备份、不导出，删图连带删，
  孤儿扫描兜底，重装重算。

## 1. 四层定义

### 1.0 L0 入库（`MediaManager.saveImage` → Rust `probe`）

入口只有两个用户主动的（相册选图、粘贴 data URI）加两个被动的（同步拉图、备份导入）。
被动入口**不改名、不改正文**（改名等于一次编辑，会搅进 LWW），只做预热。

| 魔数 | 动作 | 后缀 |
|---|---|---|
| JPEG（baseline / progressive 都算） | 原字节直存 | `.jpg` |
| PNG / WebP / GIF / BMP | 原字节直存 | 按魔数 |
| HEIC / HEIF | picker 侧 photo_manager 转 JPG q95（下文）；粘贴与历史文件走 `IHeifDecoder` | `.jpg` |
| 其它（TIFF / AVIF / 未知） | 原字节直存，展示走封顶兜底；两端都解不了就是破图 | 原后缀或 `.jpg` |

落盘后 `ImageDerivatives.warm` fire-and-forget（§1.2 的闸门）。读头只为拿宽高与方向，
不进数据库：JPEG 读头是微秒级，`ImageSizeManager` 的 LRU 够用，不为它加 schema。

**HEIC 转码维持现状（2026-09-02 拍板）**：picker（`asset_file.dart`）对 HEIC 不取 originFile，
让 photo_manager 在原生后台按原始尺寸出一张 JPEG q95，HEIC 从来进不了 `saveImage`。已知
代价并接受：iOS 侧是 `UIImageJPEGRepresentation`，EXIF（拍摄时间、GPS、相机）丢失，默认
`resizeMode fast` + `opportunistic` 尺寸与画质不精确可控；Android 侧 Glide 解码再压，EXIF 同样
丢。`saveImage` 里的 `IHeifDecoder`（heif_converter）只兜粘贴与历史 `.heic`，「图片优化」
一次性跑，Android 主线程同步解码的问题只在那一刻出现，不值得为它自建通道。

### 1.1 L1 原件

`image/<image-uuidv7>.<ext>`，不可变。所有「出去」的路径只认这一层：

- 存相册 `Gal.putImage(原路径)`、系统分享、导出 Markdown / Word / PDF 内嵌。
- 远端同步、局域网同步、本地备份 zip：`getDirFileName` 不递归，天然看不见 `thumb/`。
- 删除一律走 `AppFiles.deleteImage`（原件 + 全部派生物）。

### 1.2 L2 派生物（`ImageDerivatives`）

两档不变：`s = 512`、`m = 1280`（宽度，物理像素）。按宽度缩不按长边（解码侧
`ResizeImage(width:)` 语义，按长边竖图会更糊）。

**编码按源的透明通道分两种（2026-09-02 拍板，取代 WebP q78）：**

| 源 | 派生物 | 理由 |
|---|---|---|
| 不带 alpha：JPEG、WebP 照片、不透明 PNG、GIF 首帧、BMP | turbojpeg JPEG q82；JPEG/WebP/GIF/BMP 源 4:2:0，PNG 源 4:4:4 保文字边缘 | 编码比 WebP 快约 8 倍、列表解码快 2–3 倍；体积多约 50%，但派生物只占原件的 4%→6%，用户总存储差 2% |
| 带 alpha：贴纸类 PNG、透明 GIF | `png` crate 无损 | 保透明，深色模式格子里不出白底方块；这类图极少，体积无所谓 |

文件名 `image/thumb/<uuid>_<w>.jpg` 或 `.png`。展示端不探测内容：源是 `.jpg` 只认 `.jpg`；
源是 png / gif / webp 的先查 `.jpg` 再查 `.png`。后缀不在这两个里的派生物（开发期的
`.webp`）一律算 stale，2.8.0 未发布，没有用户持有旧派生物。

派生物从来不是「不转码」：它本来就是一张新编码出来的图，「跟源格式走」只在源是 JPEG
时省时间，PNG 源照搬 PNG 是一张 512 宽的照片 350KB、1280 宽 2MB，方向反了。所以按透明
通道分，不按源格式分。

**生成路径按源格式分两条：**

| 源 | 解码 | 12MP 成本（手机） | 48MP 峰值内存 | 闸门 |
|---|---|---|---|---|
| JPEG | turbojpeg N/8 IDCT 缩放解到「刚不小于 m 档」，fir 缩到 1280，编 m，链式再缩 512 编 s | 约 20ms（解 10 + 编 7 + 缩 3） | 约 2MB | `Pool(核数/2)` |
| PNG / WebP / GIF / BMP | `image` 全解 | 约 120ms（解码占大头） | 144MB | `Pool(1)` |

EXIF 方向：先缩后转，只转小图（已落地）。`.part` 写完 rename，半张图不会被当成有效档位。

**展示端按需生成（2026-09-02 拍板：加，条件是快）**：上午定「只查不生成」是因为一张 150ms
串行，一屏要弹几秒。JPEG 快路径把它压到 20ms 且可并行，一屏 100ms 内填满。规则：
`resolve` 缺档时，源是 JPEG 且 `probe` 判定可缩放解码的就地生成（`Pool(核数/2)`，在飞
按路径去重）；非 JPEG 仍只由预热与「图片优化」生成，滚动路径上永远不出现 144MB 的解码。
**门槛写进 P1 验收**：真机 12MP → s 档按需生成 ≤ 30ms、一屏 20 格 ≤ 150ms 填满；达不到
就退回只查不生成，开关留在 `ImageDerivatives` 一处。

### 1.3 L3 展示

**列表 / 日历 / 媒体库 / 首页**：`MediaImage(path, tier:, decodeWidth:)` 不变。缓存键
=（路径, 档位, decodeWidth），不含格子宽；固定 dp 的容器才传 `decodeWidth`。档位缺失时
退回原图按档位宽夹住解（JPEG 走引擎 DCT 缩放，位图小，熵解码仍全量）。

**编辑器正文**：`appMediaResolver` 供 m 档，原图不进 webview。

**看图页**：新 `OriginalImageView`，放进 `PhotoView.customChild` 保住 hero、下滑关闭、翻页。
三层叠加，内存由 Dart tile 缓存 64MB + Rust 带缓存 96MB 封顶，与图片分辨率无关：

1. **overview**：`MediaImage(path, tier: .m)`，网格来的话直接命中缓存，首帧即有像素。
2. **fit 层**：就是 tile 层在 fit 比例下的粗档（24000² 的图 sample 8 解成 3000² 的整图带），
   不是单独的一趟；整图带 ≤ 48MB 就钉住不淘汰，缩回去零等待。
3. **tile 层**（2026-09-02 改按 pixa 的 tile 模型，用户拍板）：`TilePlanner` 按 PhotoView
   的 scale 与 position 逆变换出视口的源像素矩形，取 2 的幂 sample 使解出的密度落在屏幕
   的 0.58–1.15 倍，tile 为 512 × sample 源像素见方，可见 tile 按离中心距离排序、上限 64、
   外圈半屏预取（> 50MP 不预取；可见 + 预取总数封顶 64 块 = 64MB）。规划去抖 60ms；一批最多 48 块交 Rust `decode_tiles`
   **一次解并集**（系统相册 `BitmapRegionDecoder` 也是整个可见区域一次解）→ RGBA 零拷贝到
   Dart → `decodeImageFromPixels` 并行上传 → 缓存（64MB 按字节 LRU，细档保留在粗档之上）→
   `drawImageRect` 画在 child 坐标里，粗档先画细档盖上，放大过程就是「模糊到清晰」。tile 层
   自成 `RepaintBoundary` 且 `shouldRepaint` 恒 false：手势期间变换由合成器套在层上，只在
   有新块时重画。Rust 侧**带缓存**：整张缩放图 ≤ 48MB 就整张一条带并钉住，否则同一行 tile
   共用一条「全宽 × tile 高」（旋转图是「全高 × tile 宽」）的带，预算 96MB；持锁解码，两路
   并发请求同一行只解一次。**restart marker 随机访问**（`restart.rs`）：带对齐 DRI 的文件建
   RST 索引后每条带只熵解码覆盖它的段，按 8MB 一块 ≤ 6 线程并行；没有 DRI 的文件 baseline
   跳过的行仍要熵解码，一趟到底。长按 ⓘ 的调试叠层能看到 sample、在飞 / 排队、缓存与
   `RST` 状态。

**格式覆盖（2026-09-03）**：tile 层是格式无关的，Rust 一个 `RawDecoder` 后端一种格式：

| 格式 | 后端 | 随机访问 | 一条带的代价 |
|---|---|---|---|
| JPEG baseline | turbojpeg 裁剪 + 缩放；有对齐 DRI 走 restart 索引 | 有 DRI 时有 | 有 DRI：只解覆盖的段、并行；无：整趟熵解码 |
| JPEG progressive | 不能区域解（整幅系数缓冲）。> 16.7MP 的入库预热时 `tj3Transform` **无损**转一份 baseline 副本 `<uuid>_base.jpg`（带 restart marker，≤ 64MP），看图页解副本；≤ 16.7MP 的走引擎封顶路径已是全分辨率 | 副本有 | 同 baseline 带 DRI |
| PNG | `png` crate 流式逐行解，窗口之上的行解完就丢，窗口内按 1/denom 盒式平均累进输出；内存 = 一行 + 输出块 | 无 | 整幅 inflate 到带底（48MP 约 0.5s）|
| WebP | libwebp `use_cropping` + `use_scaling`（RGBA 外部缓冲）；有损 1/1 时起点对齐偶数再裁；VP8L > 16MP、动图不接 | 无 | 整幅熵解析，裁剪省的是滤波与输出 |
| GIF / BMP / 其它 | 不做 | | 引擎解原图、最长边封顶 4096 |

`probe().region_decodable` 按上表判定（PNG 排除 Adam7 隔行，WebP 排除动图与超限无损）；
看图页对 progressive JPEG 另问 `ImageDerivatives.ensureBaseline`，副本不在就现转（重闸门，
24MP 约一秒，期间先用打底图）。

### 1.4 L4 出口

存相册 / 分享 / 导出 / 同步 / 备份都拿 L1。HEIC 转出的 JPG 就是它在本库的「原图」（§1.0）。

## 2. Rust 侧（`fast_image/rust`，原生库 `libfastimage`）

**2026-09-03 拆包**：整条管线（Rust + Dart）搬进 `packages/foundation/fast_image`，自带 FRB 与
第二个原生库 `libfastimage`；Dart 公开名一律 `Fast` 前缀（`FastImage` / `FastImageTier` /
`FastImageDerivatives` / `FastTilePlanner` / `FastTileImageView` / `FastTileImageViewer` /
`FastTileSource` / `FastImageCodec` / `FastRegionDecoder`），目录与日志由 `FastImageRuntime.configure`
注入，看图页的壳留在 `moodiary_components`。

模块（`rust/src/codec/`）：`turbo.rs`（读头 / N/8 缩放 / 裁剪 / 编码 / 无损转码的安全封装）、`region.rs`
（格式无关：`RawDecoder` trait、转正坐标、带缓存）、`jpeg_region.rs` / `png_region.rs` /
`webp_region.rs`（三个后端）、`restart.rs`（RST 索引 + 分段并行）。FRB 门面在 `rust/src/api/image.rs`：

```rust
pub struct ImageProbe { format, width, height, progressive: bool, region_decodable: bool }
pub fn probe(path) -> Result<ImageProbe>;                      // JPEG 走 tj3DecompressHeader，其余走 image
pub fn make_thumbnails(path, targets, quality) -> Result<ImageMeta { width, height, ext }>;
pub fn to_baseline_file(path, out) -> Result<()>;     // progressive → baseline 无损副本（≤ 64MP）
pub fn contain_to_file(path, out, CompressSpec { format: Jpeg | Png, .. });   // 导出用

#[frb(opaque)]
pub struct RegionDecoder;                // 一个看图会话一个：按魔数挑后端（JPEG / PNG / WebP）+ 带缓存
impl RegionDecoder {
    pub fn open(path) -> Result<Self>;
    #[frb(sync)] pub fn probe(&self) -> ImageProbe;
    pub fn random_access(&self) -> bool;  // JPEG 带对齐 restart marker；第一次调用扫一遍文件
    /// 转正坐标系的矩形 + 分母 {1,2,4,8}；内部映回原始朝向、对齐 iMCU、解完再把小块转正。
    pub fn decode_tiles(&self, rects: Vec<TileRect>, denom: u8)
        -> Result<Vec<TilePixels { x, y, width, height, pixel_width, pixel_height, rgba }>>;
    pub fn decode_tile(&self, x, y, width, height, denom: u8) -> Result<TilePixels>;
}
```

- `TJPARAM_MAXPIXELS` 钉 1000MP（24000² 要能过）；内存上界由输出侧预算兜：缩略图 N/8、
  带 ≤ 48MB、restart 块 ≤ 8MB 拷贝 × ≤ 6 线程。`TJPARAM_MAXMEMORY` 没设。
- **缩放系数只认 N/8 十六档，且按约分后的分数查表**（`turbo::set_scale`，4/8 要写 1/2）。
  原先 `scale_denominator` 给出的 1/3、1/5、1/6、1/7 会被 `tj3SetScalingFactor` 拒掉，4000 宽
  的 12MP 出 1280 档就撞上，2026-09-03 修。缩略图目标尺寸按源图比例算，不按上一级：中间级
  向上取整会把比例带偏一像素。
- 输出 `TJPF_RGBA`；`Vec<u8>` 经 DCO 是 `DartExternalTypedData` **零拷贝**（FRB 给 allo-isolate
  开了 `zero-copy`，Rust 的 Vec 挂成 peer 由 finalizer 释放），进引擎 `decodeImageFromPixels`
  那次拷贝是唯一一次。Dart → Rust 走 CST 有拷贝，但只传路径与矩形。
- SIMD 已核实：Android 交叉产物 `WITH_SIMD=ON`、`NEON_INTRINSICS=ON`、`-O3`，14 个 `*neon`
  目标文件（IDCT / 色彩转换 / 上采样）。**Huffman 解码在 libjpeg-turbo 里没有 SIMD**（只有
  编码端），缩放与裁剪省掉的正是 SIMD 覆盖的那部分，剩下的熵解码是纯标量串行，所以没有
  DRI 的超大图仍是整趟。`FASTUPSAMPLE` / `FASTDCT` 不开：4:2:0 快 10% 上下，换色度块边。
- turbojpeg-sys 写法：`default-features = false, features = ["cmake"]`，`TURBOJPEG_SOURCE=vendor`、
  `TURBOJPEG_STATIC=1`。不开 `require-simd`：arm64 的 NEON intrinsics 照编，x86_64 CI 无 NASM
  只是没 SIMD 跑测试。`webp` crate 已移除；`image` 的 `webp` feature 留着解 WebP 源（缩略图）。
- **libwebp-sys 0.14.4 回来了，只为 WebP 区域解码**（libwebp 1.5，`cc` 编译，`neon` feature；
  没有只编解码器的 feature，靠 `--gc-sections` 把编码器丢掉）。libwebp 的裁剪不省熵解析，
  有损解码走 YUV 4:2:0 会把裁剪起点向下对齐到偶数（1/1 时自己对齐再裁一行一列）；裁剪尺寸
  不是 d 的整倍数时面积平均有不到一个输出像素的漂移，只出现在贴右 / 下边缘的块。
- **`png` 0.18.1 直接依赖**：`next_row` 流式，`EXPAND | STRIP_16 | ALPHA` 归一到 RGBA / 灰 + alpha
  （灰不会扩成 RGB，自己复制）；Adam7 隔行 `next_row` 只给逐 pass 子行，要整幅缓冲，不接。
- **`tj3Transform` 无损转 baseline**：系数原样搬、`TJPARAM_RESTARTROWS` 与 `SAVEMARKERS`（默认
  全部带上，EXIF 方向不丢）都生效；要整幅系数缓冲（4:2:0 约 3 字节 / 像素），64MP 封顶。
- `optimize_to_file` 已删；`contain_to_file` 目标只剩 JPEG / PNG。
- hook 已加两样：Android 从 `cCompiler` 路径推 NDK 根，给 cmake-rs
  `CMAKE_TOOLCHAIN_FILE_<triple>` 与 `ANDROID_NDK_ROOT`；iOS 模拟器传 `SDKROOT`（cmake-rs 不
  区分 `-sim` 三元组）。

## 3. 并发与内存预算

| 路径 | 峰值内存 | 并发 |
|---|---|---|
| 列表解一档派生物 | 512 宽约 1MB 位图 | 引擎 IO 线程池，ImageCache 100MB 自然淘汰 |
| JPEG 预热 / 按需生成 | N/8 解码，48MP 出 1280 档解 2/8 ≈ 9MB | `Pool(核数/2)`；≥ 6MB 且带 DRI 的文件分段 ≤ 6 线程 |
| 非 JPEG 预热 | 全解，48MP 144MB | `Pool(1)`，且不在滚动路径上 |
| 看图页 fit 层 | 就是 sample 8 的整图带，≤ 48MB 时整张钉住 | 同 tile 层 |
| 看图页 tile 层 | ≤ 1MB / 块，规划内 ≤ 64 块 + 缓存 64MB；Rust 带 96MB（只钉最粗一档整图带）；restart 块拷贝 ≤ 8MB × 6 | 一批 ≤ 48 块一次解，去抖 60ms，按距离排序，半屏预取 90ms 后补 |
| 原图封顶兜底（非 JPEG） | 最长边 4096 → ≤ 64MB | 引擎 |

同步拉几千张时读头、查档、生成全在闸门里，句柄数有界（iOS 软上限 256）。

## 4. 拍板记录

全部拍板（2026-09-02）：

- **派生物 JPEG / PNG，libwebp 出仓**（§1.2）。
- **展示端按需生成加上**，JPEG 快路径、非 JPEG 关，真机达不到 §1.2 的门槛就退回。
- **HEIC 转、不存 HEIC，转码就用 photo_manager 输出的 JPEG**（§1.0）。曾备选「自建
  MethodChannel 走 ImageIO / ExifInterface 保 EXIF 与 ICC」，用户接受元数据丢失，不做。
  Flutter 两端其实都能解 HEIC（iOS ImageIO、Android 9+ `ImageDecoder`），「不转」也走得通，
  但 Rust 缩略图、webview、导出、Android 8、将来桌面端都要各补一条平台分支，不做。
- **GIF 动画保留**：原字节直存所以看图页能动，缩略图是首帧。
- **EXIF 方向不烤进文件**：`tj3Transform` 只有边长是 16 的倍数才无损，4000×3000 就不行；
  方向映射在 Rust 一处活着。

用户唯一的硬条件是原件不变。

2026-09-03 追加：

- **restart marker 随机访问做**：先以为是月球图专属被否；弄清是 JPEG 标准（T.81 的 DRI /
  RSTn）的通用特性、相机与修图软件导出大多带之后拍板做。没有 DRI 的文件零影响。
- **不为超大图做 1/4 派生物金字塔**：restart 路径覆盖了带 DRI 的文件；没有 DRI 的超大图仍是
  整趟，等真有抱怨再做（磁盘约原件 6%）。
- **`FASTUPSAMPLE` / `FASTDCT` 不开**（§2）。

## 5. 分期

| 分期 | 内容 | 状态 |
|---|---|---|
| P0 | 原字节直存、两档缩略图、`MediaImage`、4096 封顶 | 已落地（2026-09-02） |
| P1 | turbojpeg 进仓、派生物 JPEG / PNG、按需生成 | 已落地，真机验收（2026-09-02） |
| P2 | 看图页三层、tile 规划、带缓存 | 已落地，真机验收（2026-09-02） |
| P2.5 | restart marker 随机访问 + 分段并行、N/8 缩放修正 | 已落地，真机验收（2026-09-03，用户：体验很好） |
| P2.6 | tile 扩到 PNG / WebP / progressive JPEG（`RawDecoder` 后端） | 已落地，模拟器验收（2026-09-03） |
| P2.7 | 对抗式审查修复（四路代理 + 复核） | 已落地（2026-09-03） |
| P3 | 无 DRI 超大图金字塔、ICC、Adam7 PNG、动图 | 按需，未排期 |

- **P0（已落地）**：原字节直存、两档 WebP、`MediaImage`、展示端只查不生成、看图页 4096 封顶、
  Rust 先缩后转、视频封面不走档位、「图片优化」走索引。
- **P1 turbojpeg 进仓（2026-09-02 落地并真机验收，OnePlus 13 / profile 包）**：turbojpeg-sys +
  hook 两处环境变量；`probe`；`make_thumbnails` 的 JPEG 快路径、JPEG / PNG 编码与双闸门；`webp`
  crate 出仓；`candidateNames` / `stale` 认两个后缀；展示端 JPEG 按需只生成要的那一档
  （`_generate(only:)`）再补齐，`_absent` 记「源不比档位宽」。实测：12MP 相机 JPEG 两档 86ms，
  1440×3168 截图 108ms（8/8，编码占大头），4 张并发约 130ms；24000² / 576MP / 313MB 两档
  3078ms，内存无残留。`.so` +1.06MB（含 rayon，减 libwebp）。
- **P2 看图页三层（2026-09-02 落地并真机验收）**：Rust `region.rs` 的 `JpegRegionDecoder`
  （mmap 读文件、`tj3SetCroppingRegion`、转正坐标、八种方向逐像素测试）+ 带缓存；Dart
  `TilePlanner`（pixa 模型）+ `OriginalImageView`（`PhotoView.customChild`，overview / tile /
  兜底）。实测：12MP `open` 4ms、fit 12 块约 50ms、放大后 sample 1 的 14 块约 100ms，同行 tile
  命中带 0ms，PSS 增量约 30MB；月球图 `open` 201ms、fit 首块 2.9s（一趟 313MB 熵解码）随后
  35 块各 1ms。第一版放大后每换一行带 1.2–2.9s、双击动画途中还连带解了中间比例的两批，放到
  最大要近一分钟才清晰；改成**一批可见 tile 的并集一次解**（`decode_tiles`）、规划去抖、超过
  50MP 不预取外圈之后，双击放到 2:1 原生像素约 3s 清晰，PSS 增量 +35MB。放大上限改成
  `max(covered×3, 每源像素 2 物理像素)`：原先按屏幕比例定的 covered×3 让 24000² 的图只能看到
  原图四成清晰度。`MAX_SOURCE_PIXELS` 放到 1000MP。**第二轮迭代（用户反馈来回缩放卡顿、
  怀疑任务没取消）**：卡顿真因是 PhotoView 每帧重建让 tile 层逐帧重画，改 `RepaintBoundary` +
  `shouldRepaint` 恒 false + 不按视口裁剪 + 标签排版缓存；整图带被 64MB 预算淘汰导致缩回去再解
  一趟，改钉住整图带、带预算 96MB、tile 缓存 64MB；去抖 100→60ms；一批位图并行上传。长按 ⓘ
  的调试叠层（sample 颜色、在飞 / 排队、视口框、HUD）随之加上。
- **P2.5 restart marker 随机访问 + 并行（2026-09-03 落地并真机验收）**：`restart.rs`。带 DRI 且
  间隔与 MCU 行对齐的 baseline JPEG（相机、Photoshop / Lightroom、libjpeg 系导出常见），第一次
  解码时 memchr 扫一遍文件建 RST 偏移索引（313MB 主机 18ms），之后每条带只熵解码覆盖它的段：
  拼「剔掉 APPn 的原头（SOF 高度改小，保留 Adobe APP14）+ 从对应 RST 起的熵数据（编号从 0
  重排）+ EOI」交给 turbojpeg，段与段独立所以按 8MB 一块切、最多 6 线程并行；每块上下多带一个
  间隔再裁掉，4:2:0 的 fancy 上采样在块边界就与整图解码逐字节一致（测试钉住）。
  `make_thumbnails` 对 ≥ 6MB 的 JPEG 也走这条并行路。主机实测月球图：fit 1/8 整图 1.55s →
  0.29s（6 线程），1:1 中段 512 行带 752ms → 15ms（4 线程）。没有 DRI 的文件零影响。顺手修了
  一个真 bug：turbojpeg 只认 N/8 十六档缩放系数，原先 `scale_denominator` 给出的 1/3、1/5、
  1/6、1/7 会被 `tj3SetScalingFactor` 拒掉，4000 宽的 12MP 出 1280 档就撞上；现在一律 N/8 且
  约分后再传，缩略图目标尺寸改按源图比例算。真机（OnePlus 13 / profile）用户实测：体验好。
- **P2.6 多格式 tile（2026-09-03 落地，模拟器验收）**：`region.rs` 抽成格式无关的 `RegionDecoder`
  + `RawDecoder` trait，JPEG 后端搬进 `jpeg_region.rs`，新增 `png_region.rs`（流式逐行 + 盒式
  降采样，逐字节等于整图解码后同一套平均）、`webp_region.rs`（libwebp 裁剪 + 缩放，偶数对齐
  再裁）；progressive JPEG 走 `tj3Transform` 无损转出的 baseline 副本（`ImageDerivatives.
  ensureBaseline`，入库预热顺带生成，删图连带删）。`probe().region_decodable` 按格式判定；看图
  页的门从「是 JPEG」改成「探头说能」。对 pixa 的三处改进：PNG 边解边缩（pixa 全分辨率取窗
  再缩，sample 8 一块 64MB 直接被预算拒掉）、progressive 不按 4MP 硬拒而是无损转码一次永久
  受益、WebP 奇数起点先对齐再裁而不是把对齐后的块拉伸（pixa 的 tile 会偏一像素）。模拟器
  （API 35，arm64）实测 6000×4500 的有损 WebP、PNG、progressive JPEG 三张：fit 9 块、双击后
  sample 1 的 45 块 4 秒内全绿。顺带：可见 + 预取总数封顶 64（原先预取不计入预算，缓存冲到
  109MB）、带 alpha 通道但全不透明的源改编 JPEG 派生物。
- **P2.7 对抗式审查（2026-09-03）**：四路代理（Rust 解码器 / 派生物逻辑 / Dart 看图页 / 构建
  依赖）各自带复现地攻，我逐条复核后修了这些（全部有测试或代码路径可指）：
  - 派生物：**视频封面走了派生物管线**又被孤儿扫描当野文件删，永远重算 → 派生物只给
    `AppFiles.imageDir` 里的原件算（`_eligible`），封面不传档位；`resolve` 的按需生成没进
    `_inflight`，两路并发同写一个 `.part` → `_dedup` 串行 + Rust 临时文件名带进程号与序号；
    生成失败不记 `_absent` 会在滚动路径上无限重试 → 失败也记；后缀撒谎（叫 `.jpg` 的带 alpha
    PNG）写出 `.png` 而 Dart 只找 `.jpg` → 两种后缀一律都查；快慢闸门按扩展名分 → 读三个魔数
    字节分；同步预热堵住看图页 → 按需 / 预热 / 全解 / 转码四个闸门分开；**按宽缩的档位遇到长
    截图是 512×15360、31MB 位图** → 高封顶 3× 档位宽（Rust `tier_target` 与 Dart `_fitWidth`
    同口径），比档位窄但很高的图也出档；`stale()` 会删正在写的 `.part` → 一小时内的放过；
    `ImageOptimizer` 用 `deleteImage` 删旧 HEIC 顺带删掉了新 JPG 的派生物 → 只删旧原件。
  - 看图页：**控制器跨页元素复用**，PageView 销毁两页外的页后翻回来带着旧平移量整页白屏 →
    控制器归 `_TilePage` 自己；**探头回来前先挂了整解原图的 PhotoView**，每张图白解一张 4096
    封顶的位图进缓存 → 探头期间只画 m 档；邻页各开一份解码器与 tile 缓存 → 只有当前页开
    （`active`，切页 teardown / 再开）；预算只在规划时淘汰，插入后能到两倍 → 插入后再淘汰一
    次；`maxVisibleTiles` 64 在竖屏密度带下沿会被平移触发升档变糊（可见 6×12 = 72）→ 升档阈值 96、可见 + 预取总数另封顶 64，预取圈从一屏改半屏（一块 1MB，整圈一屏是可见数的八倍）；
    `decodeImageFromPixels` 失败时回调永远不来、`_busy` 卡死 → 改走 `ImmutableBuffer` →
    `ImageDescriptor` → `Codec` 的 Future 链；一批里一块矩形落在图外整批报错 → Rust 跳过、
    Dart 按覆盖矩形对号；第一批就失败的文件退回引擎路径而不是一批批撞。
  - Rust：**整图带每档都钉住**，12MP 四档 64MB 永远不放 → 只钉最粗那档；`Rect::right()` u32
    溢出 → saturating；PNG `STRIP_16` 是截断、缩略图那路是四舍五入，16 位源两层差一灰阶 →
    自己按 16 位读四舍五入（测试改用真 16 位样本）；PNG 上限 1000MP、有损 WebP 268MP 对没有
    随机访问的后端太大（每条带整幅解、行带放不下就逐块重解）→ PNG 100MP、有损 WebP 64MP；
    `to_baseline_file` 会把 12 位 / 已是 baseline 的也转 → 先查；JPEG 填充字节 `FF FF D0` 让
    索引静默放弃；CMYK / YCCK JPEG 当成可区域解（turbojpeg 不给 RGB）。
  - 构建：turbojpeg-sys 的许可证文本被 cargo-about 抓成了 Doxygen 的 `menudata.js` → about.toml
    clarify 指向 README.ijg + LICENSE.md；libwebp-sys 补上 vendored libwebp 的 BSD-3 文本。
  - 审查证伪 / 未采纳：Rust 侧所有 unsafe、restart 分段（7 种子采样 × 多种间隔 × 600 次差分
    逐字节一致）、2700 个截断 / 翻位文件零 panic、八方向覆盖矩形 7500 次随机请求，都稳；
    FRB opaque 在飞时 dispose 不会释放（`Arc` 在调用前就 clone）；libwebp 全编进来靠
    gc-sections 丢编码器这句在 iOS 上不成立（cc 不给 `-ffunction-sections`），靠的是 ld64 的
    `-dead_strip`，结论一样。
- **P3 按需**（没有用户抱怨就不做）：没有 DRI 的超大 JPEG（1/4 派生物金字塔，磁盘约原件 6%）、
  ICC 校色、Adam7 隔行 PNG（可把前几个 pass 当低分辨率层，要整幅缓冲）、动图 WebP / GIF。
  HEIC / AVIF / JXL 天生分 tile 但解码器体积否决过，且 HEIC 入库即转 JPG。

## 6. 不变量（别改回去）

- 原件目录只放原件；派生物永远在子目录，永远不同步。
- 列表里永远不解原图；看图页永远不整解原图到 1:1。
- 缩略图按宽度缩；EXIF 方向先缩后转；编码按透明通道选 JPEG / PNG，不按源格式。
- 单 .so：turbojpeg 静态链进 `moodiary_rust`，不另起原生库。
- restart 索引只加速不改语义：分段解码必须与整图裁剪解码逐字节一致（`restart.rs` 测试钉住）。
- 派生物只给 `image/` 目录里的原件算；快慢路按魔数不按扩展名；派生物高不超过档位宽的 3 倍。
- 看图页同一时刻只有当前页持有解码器与 tile 缓存。
- 看图页的 tile 只在内存里，永远不落盘；落盘的派生物只有 `make_thumbnails` 出的两档加
  progressive JPEG 的 baseline 副本（像素与原件逐字节相同）。
- 每种格式的区域解码都要有「与整图解码同一块逐字节一致」的测试钉着（WebP 有损与贴边缩放
  除外，那两处是 libwebp 自己的重采样，允许几个灰阶）。
