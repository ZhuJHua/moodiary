# 分享 = 单篇导出：图片格式设计（2026-09-04）

> **STATUS: ✅ 已实现（2026-09-04）。** P0–P6 全部落地：`fast_image` 加了 `FastPngWriter`
> 流式写长 PNG；`moodiary_export` 加了 `ImageComposer`（离屏管线 + 分带）与 `image_card/`
> 三件套；`ExportFormat.image` 接进 `ExportService`；分享弹窗 + 图片预览页 + 批量「预览样张」
> 全部就位；`moodiary_share` 已删除，日记页经 `DiaryShare` 挂钩（components 里的进程内注册点）
> 落到导出包。下面的设计正文保留为记录。

> 输入：`moodiary_share` 全包（520 行）、`moodiary_export` 全包（3287 行）、`fast_press` 的 IR 契约、`webview_flutter` 平台视图截图能力核查、`MediaManager.saveToGallery` 现状。

## 0. 结论先行

**分享与导出合并成一条链，图片只是第四种 writer。**

```
ExportScope ──► List<Diary> ──► ExportDoc(IR) ──┬─► MarkdownWriter  → .md
   (范围)          (仓储)         (tiptap→IR)    ├─► fast_press docx → .docx
                                                ├─► fast_press typst→ .pdf
                                                └─► ImageComposer   → .png   ← 新增
```

三件事随之定下来：

| 问题 | 结论 |
|---|---|
| 「给 tiptap 截图」怎么实现 | **不截 WebView**（平台视图进不了 Flutter 的光栅化），改为 **IR → Flutter 离屏渲染 → PNG**，与 pdf/docx 共用同一条 Scope→IR 链 |
| 分享和导出两个包怎么摆 | **`moodiary_share` 整包并入 `moodiary_export` 后删除**。两者同为 feature 层，禁止互 import；而「分享 = scope 只有一篇的导出」本来就是同一件事 |
| 「复制文本」 | 删除。它既不是分享形态也不是导出格式，占着弹窗的位置 |
| 哪些格式有预览 | **本期只有图片**。Markdown / Word / PDF 的预览暂缓（方案与成本已核完，记在 §2.5，将来要做直接照做）。这三种的单篇分享仍然是快捷操作：点了就生成，直接拉起系统分享面板 |
| 分享要不要给配置项 | **不给**。分享是快动作：弹窗 → 预览 → 存相册 / 发出去，两步到底；样式取导出页存下的默认值，**只读不写**。要调样式去批量导出页，配置只有一个家 |

单篇（分享）与多篇（导出）唯一的差别是 **scope 从哪来**，以及图片格式多一个**预览页**。

## 1. 现状盘点

### 1.1 分享（`moodiary_share`，520 行）

- 入口：`diary_page.dart:508` → `ShareRoute(diaryId).push()` → 整页 `SharePage`。
- 内容源是 **`diary.contentText`**——纯文本，图片 / 标题层级 / 列表 / 表格 / 代码块全部丢失。
- 两个模版（`minimal` / `note`）各自硬编码一套颜色常量，与 mui 主题脱钩（`Theme.of(context).colorScheme.primary` 是唯一的连接点）。
- 出口两个：`Clipboard`（无用）、`SharePlus`（分享面板）。**没有保存到相册**——而 `MediaManager.saveToGallery` 早就在 `moodiary_files` 里了（媒体库在用）。
- 卡片宽度固定 360dp，`pixelRatio: 3` → 1080px 宽。长日记直接超出可导出高度，无任何处理。

### 1.2 导出（`moodiary_export`，3287 行）

结构是健康的，图片格式接进去成本很低：

- `ExportScope`（sealed：all / category / dateRange / picked）→ `List<Diary>`。
- `TiptapToIr` 把 tiptap JSON 走成 9 种 `IrBlock`（Paragraph / Heading / List / Quote / Code / Divider / Image / Media / Table），旧 markdown / Quill 日记先就地转 tiptap，**全程不经 WebView**。
- `_MediaStage` 按 `ExportMediaPolicy`（embed / placeholder / none）把媒体转码暂存到工作目录。
- `ExportService.run()` 统一编排：进度（converting / writing / serializing）、取消（`press.CancelToken`）、工作目录生命周期、zip 打包。
- `FormatExportPage` 一页伺候三种格式，差异只在「排版」分组。
- 设置按格式分别持久化在 `MoodiaryKVs.exportSettings`（一坨 JSON）。

**唯一的坏味道**：产物一律直接拉起系统分享面板（`shareExported`），没有「保存到本机 / 相册」这一路。

## 2. 关键决策：图片怎么画

用户原话是「单纯给 tiptap 截图」。四条路都核过：

### A. 直接截 WebView —— 否决（做不到）

`RenderRepaintBoundary.toImage()` 光栅化的是 Flutter 自己的图层树，**平台视图（Android 的 hybrid/TLHC composition、iOS 的 `UIKitView`）不在其中**，截出来是空白或黑块。而 `webview_flutter` 也没有暴露 `WKWebView.takeSnapshot` / Android `WebView.capturePicture`。这条路不是「难」，是没有接口。

### B. 页面内 JS 截图（html-to-image / modern-screenshot）—— 记录为 fallback，不选

在编辑器页面内用 `foreignObject → canvas → dataURL`，再经现有 bridge 过桥。保真度确实最高（就是编辑器自己的 CSS），但：

1. **只能截当前这篇**。多篇导出要起离屏 WebView 逐篇 load → 等图 → 等布局 → capture，串行且脆；
2. foreignObject 对自定义字体必须内联，WKWebView 上偶发字形丢失；
3. canvas 有单边与总面积上限，长文仍要自己分片；
4. 编辑器 bundle 增重，且 `flutter test` 覆盖不到；
5. 与 pdf/docx 两条链彻底分叉——违背「分享和导出本质上是一个东西」。

### C. IR → Flutter 离屏渲染 —— **选中**

`ExportDoc.blocks` 已经是排版无关的 9 种块，Flutter 侧写一个渲染器把它画成一张卡片，再离屏光栅化成 PNG。

- 与 md/docx/pdf 同源，批量、进度、取消、工作目录全部白拿；
- 无 WebView，导出页不必等编辑器起来；
- 可单测（分带算法纯函数 + 少量 golden）；
- 版式完全归我们控制——页脚 logo、明暗、宽度、水印都是渲染器参数。

代价：编辑器的观感要在 Flutter 侧复刻一份，编辑器加了新节点时会漂。**漂移已有兜底**——`TiptapToIr` 遇到不认识的节点会收进 `ExportDoc.unsupportedNodes`，UI 弹「部分内容未导出」，图片格式沿用同一条上报。

### D. typst → PNG —— 否决

`fast_press` 已有 typst，加 `typst-render` 就能出图，排版与 PDF 完全一致。但：① 它会逼退 slim fork（要求打开 `svg` + `pdf-image`），libfastpress 18.58 → 约 35 MB，细账见 §2.5；② 沿用 PDF「**必须先导入一个 TrueType 字体**」的硬门槛（`_pdfBlockedReason`），对「随手分享一张图」是灾难性 UX。第二条与体积无关，独立成立。

## 2.5 预览：本期只做图片

**原则不变：预览的是真产物，不是示意图。** 图片这条天然成立 —— `ImageComposer` 出的那张 PNG
就是预览里显示的东西，预览与产物之间没有第二套渲染代码，也就不会漂。

Markdown / Word / PDF 的预览**暂缓**。方案与成本已经核完，将来要做照着下面做即可：

| 格式 | 可行方案 | 成本 |
|---|---|---|
| Markdown | 直接显示 `MarkdownWriter.write()` 的返回值（等宽源码） | 零 —— 这条随时可以捡起来 |
| PDF | ① `typst-render` 逐页光栅化（与产物同一份 typst 文档，逐像素同源）② Android `PdfRenderer` / iOS `CGPDFDocument` 渲染刚落盘的 PDF | ① 要把 slim fork 撤回原版，libfastpress 18.58 → 约 35 MB；② 零二进制，代价是两端各写一个薄 platform channel |
| DOCX | 没有能如实渲染的引擎。只能给「内容清单」（文件名 / 大小 / 将包含什么 / 纸张字号），**不要**用 typst 排一份「近似版式」——它会稳定地骗人，而看预览恰恰是为了确认分页 | 零 |

两条硬结论先钉在这里，省得将来重推：

- **`typst-render` 会逼退 slim fork**。它的 `Cargo.toml` 硬要求 `typst-library` 打开
  `svg` + `pdf-image`（`svg = ["dep:usvg"]`、`pdf-image = ["dep:hayro-syntax"]`），正是 fork
  关掉的那两个，外加它自带的 `resvg` / `tiny-skia` / `pixglyph`。**PDF 预览不做，fork 就不用动**
  —— 今天保持 18.58 MB 与 git rev 钉版本的现状，`typst-size-tradeoff` 那条结论继续有效。
- **无论哪条路都别引 pdfium 系的包**（`pdfrx` / `pdfx` 的部分平台会打包 pdfium，每 ABI 4~8 MB）。

**图片格式仍然走 Flutter 离屏渲染**，不用 typst 出图：§2 里否决 typst→PNG 的第二条理由
（PDF 必须先导入 TrueType 字体）独立成立，对「随手分享一张图」是灾难。

## 3. 渲染器规格（`ImageComposer`）

新文件：`packages/feature/moodiary_export/lib/src/data/image_composer.dart`（渲染器）+ `presentation/image_card/`（卡片 widget 与模版）。

### 3.1 离屏管线

不挂在可见 widget 树上（导出页可能根本没显示卡片，批量导出也不该每篇跑一帧动画）：

```dart
final boundary = RenderRepaintBoundary();
final renderView = RenderView(
  view: ui.PlatformDispatcher.instance.implicitView!,   // 兜底：null 时退回可见树 overlay
  child: RenderPositionedBox(child: boundary),
  configuration: ViewConfiguration(
    logicalConstraints: BoxConstraints.tightFor(width: widthDp),
    devicePixelRatio: scale,
  ),
);
final pipelineOwner = PipelineOwner()..rootNode = renderView;
renderView.prepareInitialFrame();
final buildOwner = BuildOwner(focusManager: FocusManager());
RenderObjectToWidgetAdapter(container: boundary, child: card)   // 3.47.2 仍在（widgets/adapter.dart）
    .attachToRenderTree(buildOwner);
buildOwner
  ..buildScope(element)
  ..finalizeTree();
pipelineOwner..flushLayout()..flushCompositingBits()..flushPaint();
final image = await boundary.toImage(pixelRatio: scale);
```

四条硬约束，违反了就是空白图或跑飞：

1. **所有异步资源必须预解码**。离屏管线不会自己跑第二帧，`Image.file` 的异步 resolve 永远来不及。图片直接 `ui.instantiateImageCodec(bytes, targetWidth: 列宽×倍率)` —— **解码时就降采样**，4000px 原图不整张进堆，以 `RawImage` 喂进树。
   > 实现时改掉了设计初稿的「先用 `fast_image` 的 `contain_to_file` 缩一份再解」：Flutter 自己的 codec 就支持 `targetWidth`，认 WebP，少一次过桥、少一份临时文件。**图片导出这条链对 `fast_image` 的唯一依赖是 `FastPngWriter`。**
2. **不吃系统字号**。树顶包 `MediaQuery(data: MediaQueryData(textScaler: TextScaler.noScaling))` + `Directionality` + `DefaultTextStyle`。导出物的字号不该随手机的显示设置变（跟 `font-scale-pipeline` 那条相反：那是给屏幕的，这是给文件的）。
3. **主题要快照**。卡片吃的是一份 `MImageCardTheme`（颜色 + 排版的纯数据），由调用方从 `context.theme` 取一次传进去——离屏树里没有祖先 `Theme`。
4. **画完立刻释放**。`toImage` → `toByteData(png)` → 落盘 → `image.dispose()`。批量导出串行，绝不并发。

### 3.2 长图：一篇永远一张

**产物张数恒为 1，高度不设上限。** 分享出去的就是一张图，用户不必理解「切了几张」，
预览页上下滚动就是全部交互。

问题只在实现侧：`toImage` 走的是 GPU 光栅化，单边受纹理上限约束（Impeller/Metal 与多数
Vulkan 设备是 16384，老设备 4096），而 1080 × 12000 的 RGBA 一次性缓冲也有 51.8 MB。
所以**分带是实现细节，不是产物形态**：

1. **量高度**：dry-run 一次（`scale = 1`，只 layout 不 `toImage`）拿到整篇的总高与每块的 y 区间。
2. **分带光栅化**：按 **2000 逻辑像素**一带切（切点落在块边界，不切开半行字），逐带
   `toImage` → `toByteData(rawRgba)`，单带峰值 1080 × 2000 × 4 ≈ 8.6 MB，用完即 `dispose`。
3. **流式落盘**：把各带的 RGBA 依次喂给 Rust，`png` crate 的 `Encoder::write_header` →
   `StreamWriter` 逐行写同一个 PNG。**全程不存在整张图的位图**，内存与篇幅无关。
   `png = 0.18.1` 已经是 `fast_image` 的直接依赖（区域解码在用），新增的只是一个
   `PngStripeWriter`（`new(width, height, path)` / `push(rows)` / `finish()`），**零新依赖、零体积**。

兜底：PNG 头里的高度是 u32，写多高都合法，但相册与社交 App 对超大图会压缩甚至打不开。
真遇到离谱篇幅（32 万字那篇外推约 50 万像素高）时**自动降档** `scale` 3 → 2 → 1 再出图，
仍然是一张，UI 不多一个选项、不弹一次询问。

### 3.3 卡片版式

自上而下四段，每段可开关：

```
┌─────────────────────────────┐
│ 2026-09-04 周四 · 晴 22°     │  ← 元信息头（common.includeMeta；位置另有开关，默认关）
│ 今天去了海边                  │  ← 标题（复用 common.includeTitle）
├─────────────────────────────┤
│ 正文：IR 9 种块的渲染          │  ← 图片/媒体按 common.media 降级
│                             │
├─────────────────────────────┤
│ ◇ Moodiary                  │  ← 品牌页脚（可关）
└─────────────────────────────┘
```

**模版只有一个**（现有 minimal / note 退休，2026-09-04 拍板）：`paper`（原稿）——跟随应用当前配色，
最接近编辑器观感，强调色 / 引用条 / 代码块底色都取自 `ColorScheme`。

明暗 `Brightness` 独立存在，默认跟随 app 当前主题。所以产物有浅色与深色两张脸，
**几何逐像素一致，只换配色层**；不存在第二套版式要维护。

**IR 9 种块的画法**：

| IrBlock | 渲染 |
|---|---|
| Paragraph | `RichText` + span 样式（bold/italic/strike/underline/code）；`href` 与 `diaryLinkId` 画成强调色下划线，不可点 |
| Heading | 1~3 级用递减字号 + 字重；4~6 级并到 3 级样式 |
| List | 项目符号 / 序号 / ☑☐（`isTask`），支持嵌套缩进 |
| Quote | 左侧 3px 竖条 + 缩进 + 次级文字色 |
| Code | 等宽字体 + 圆角底色块 + 语言角标；**做语法高亮**，走 `re_highlight: 0.0.3` 与助手同一张表（hljs 11 的 github / github-dark），按卡片明暗选表 |
| Divider | 1px 分割线 |
| Image | 预解码 `ui.Image` + `widthPercent` 的列宽百分比 + 圆角 |
| Media | 视频画封面 + 播放角标；音频画一条波形占位 + 文件名；`placeholder` 策略下都退化成一行灰字 |
| Table | 简版网格：等分列宽 + 表头底色 + 1px 边框；`colspan/rowspan` 只做合并绘制不做复杂布局 |

### 3.4 品牌页脚

logo 资源今天在 `mobile/assets/icons/appicon_{light,dark}.svg`——**app 层的 asset，feature 包够不着**（能靠 rootBundle 的键硬读到，但那是把 app 的布局知识写进 feature 包）。

**实现把资源搬去了 `moodiary_components`**（feature_base），而不是往导出包里复制一份：
`assets/brand/logo_{light,dark}.svg` + flutter_gen 的资产索引 + 一个 `MoodiaryLogo` 组件，
关于页与分享图页脚从此共用同一份文件。**`package_parameter_enabled: true` 必须开** ——
被别人 import 的包，产物里要带 `package: 'moodiary_components'`，否则宿主按裸键去自己的
bundle 里找，编译期不报、运行时才空。

关键是**必须预光栅化**：离屏树不跑第二帧，`SvgPicture` 那条异步加载链没机会完成。所以
`MoodiaryLogo.rasterize` 先 `vg.loadPicture`（context 传 null → 回落 `rootBundle`）拿到矢量图，
自己录一遍画布按 `18dp × 倍率` 转成 `ui.Image` 再进树；结果按「明暗 + 像素边长」缓存，
批量导出 300 篇只解一次。画不出来就退回只有字的页脚，不让整次导出失败。

页脚只有标识本身，没有页码——产物永远是一张图，没有「第几张」可写。

## 4. 数据模型改动

```dart
enum ExportFormat {
  markdown('markdown', 'md'),
  docx('docx', 'docx'),
  pdf('pdf', 'pdf'),
  image('image', 'png');            // 新增
}

/// 图片专属。与 markdown / docx / pdf 三块并列存进 ExportSettings。
class ImageExportOptions {
  final Brightness? brightness;     // null = 跟随当前主题
  final double widthDp;             // 360 | 480
  final int scale;                  // 2 | 3
  final bool watermark;             // 品牌页脚
}
```

`ExportCommon` **加一个字段**：

```dart
/// 元信息里的位置单独一个开关，且默认关 —— 日记页上看是自己的，发出去就是行踪。
/// 日期 / 心情 / 天气 / 分类仍归 includeMeta 管。
final bool includePosition;   // 默认 false
```

其余复用：`includeTitle` / `includeMeta` / `media` 语义不变；**`merge` 对图片的语义是
「多篇拼成一张长图」**（关掉 = 每篇一张）。位置开关对四种格式一起生效 —— md / docx / pdf
导出去同样是要发给别人的。

`ExportOutcome` 加一个字段——**单篇永远只有一张**，但多篇导出（每篇一张）会产出 N 个文件，
而相册与分享两条出口都要按文件处理：

```dart
class ExportOutcome {
  final String path;                // 单文件或 zip（保持不变，老调用点不动）
  final List<String> images;        // 图片格式下的逐张路径，其它格式为空
  ...
}
```

## 5. UI 设计

### 5.1 日记页 → 分享底部弹窗

`ShareRoute(...).push()` 换成 `MSheet.picker`（mui 已有，不新增组件）：

```
──────── 分享这篇日记 ────────
 🖼  图片          长图，可存相册     ›
 📄  Markdown     纯文本 + 素材      ›
 📘  Word         可继续编辑         ›
 📕  PDF          排版固定           ›
           取消
```

**图片有预览，另外三种没有**（§2.5），但四种都是「点了就走」的快捷操作，中间都不插配置页：

- **图片** → `/share?diary-id=xxx`（路径保留，`app_lock_observer` 里硬编码了它）：用存下的默认
  设置生成 → 预览页（§5.2）→ 保存到相册 / 分享。
- **Markdown / Word / PDF** → 同样用默认设置**直接生成这一篇**（单篇很快：typst 排一页是毫秒级），
  toast 报「正在生成」，完了直接拉起系统分享面板。没有中间页，没有预览。
- **想改设置**：去「导入与导出 → 对应格式」（§5.3）。分享侧一律只读那份设置，
  这样分享页不必长出配置项，也不会有人在分享时意外改掉批量导出的默认值。
- PDF 若还没导入字体（`_pdfBlockedReason`），点它先进字体选择页，选完继续生成 ——
  不要让用户对着一行红字自己找路。

### 5.2 图片预览页（`ImageExportPage`）—— 零配置

分享是个快动作，不是配置动作。这一页只做一件事：把**真产物**给用户看，然后让他存下来或发出去。

```
┌──────────────────────────────┐
│  ‹  图片预览                 │
├──────────────────────────────┤
│                              │
│      ┌──────────────┐        │  预览区吃掉整屏：
│      │              │        │  真实产物（RawImage），可竖向滚动看全长；
│      │  真实产物预览  │        │  右上角小标「1080 × 4200」——
│      │              │        │  这是信息，不是可点的选项；
│      │              │        │  下沿渐隐表示还有下一屏。
│      └──────────────┘        │
├──────────────────────────────┤
│ [ 保存到相册 ]   [ 分享 ]      │
└──────────────────────────────┘
```

- **样式不在这里选**：模版 / 明暗 / 宽度 / 清晰度 / 含媒体 / 水印全部取
  `MoodiaryKVs.exportSettings` 里 `image` 那一块的当前值 —— 也就是「导入与导出 → 图片」页存下的那份。
  **分享只读不写**，用户在分享页改不动设置，也就不会在这里意外改掉批量导出的默认值。
  想调样式去「导入与导出 → 图片」（§5.3），配置有唯一的家。**这一页没有任何跳转**——顶栏只有返回键，
  底部只有两颗按钮，一共三个可点的东西。
- **预览就是产物**：进页时用 `scale = 1` 渲一次给 `RawImage` 显示，点按钮时才用真实 `scale` 重渲落盘。
  所见即所得，不存在「预览 widget 与导出 widget 两份代码」的漂移。
- 「保存到相册」→ `MediaManager.saveToGallery(type: .image)`（已有；iOS 的 `NSPhotoLibraryAddUsageDescription` 已在 Info.plist）。单篇永远一张，toast 报「已保存到相册」。
- 「分享」→ `SharePlus`，一个 `XFile`。
- 渲染中底部按钮转圈禁用。长到离谱的篇幅由渲染器自动降档（§3.2），这一页不弹询问。

### 5.3 我的 → 导入与导出

「导出」分组新增一项，排在最前（最常用）：

```
导出
  🖼  图片            PNG 长图        ›
  MD  Markdown                     ›
  DOCX Word                        ›
  PDF  PDF                         ›
```

进入 `FormatExportPage(format: .image)`：范围分组照旧；内容分组多一行「包含位置」（默认关）；第三组换成「图片」（明暗 / 尺寸与清晰度 / 显示标识）——模版只有一个，不给选项行。

**底部动作条改成两颗**：「预览样张」与「导出 N 篇」。

- **预览样张**：用当前设置只跑 `scope` 里的**第一篇**，落到 §5.2 那个预览页（顶部标一行
  「样张 · 第一篇」）。全量导出前先看一眼纸张、字号、要不要元信息，比导完 342 篇再返工便宜得多。
  **只有图片配置页有这颗按钮** —— 另外三种没有预览可给（§2.5）。
- **导出 N 篇**：跑全量，进度与取消照旧。执行后：

- 每篇一张（`merge = false`，默认）→ 文件数 ≤ 9 时直接给「保存到相册 / 分享」两颗按钮；再多就打成 zip 走现有分享。
- 合并长图（`merge = true`）→ 一张（多篇之间画一条分隔与日期，仍是一个文件）。

进度沿用 `ExportPhase.converting` + `writing`（每篇一张，`writing` 的 done/total 是真实的，比 PDF 那条还准），取消沿用 `CancelToken`。

## 6. 包结构改动

`moodiary_share` 与 `moodiary_export` 同在 feature 层，**features never import each other**。而分享要用 scope / IR / 渲染器，只有两条路：把渲染器下沉到 feature_base，或者合并。选合并——分享本来就是「scope 只有一篇的导出」，下沉会把 `ExportDoc` / `TiptapToIr` / `_MediaStage` 一起拖下去，为一条包边界付两倍代价。

| 动作 | 文件 |
|---|---|
| 删包 | `packages/feature/moodiary_share/` 整个 |
| 迁移 | `ShareRoute` 的 builder 挪进 `exportRoutes()`，路径 `/share` 不变 |
| 新增 | `data/image_composer.dart`、`data/image_options.dart`、`presentation/image_export_page.dart`（预览页）、`presentation/image_card/{card.dart,blocks.dart,templates.dart}`、`presentation/share_sheet.dart` |
| 改 | `export_options.dart`（+image）、`export_service.dart`（+`_writeImage`、+单篇样张入口）、`export_page.dart`（+图片入口）、`format_export_page.dart`（+可选 scope、+图片分组、+图片页的预览样张按钮） |
| 新增（rust） | `fast_image`：`PngStripeWriter`（`new` / `push` / `finish`），流式写一张长 PNG（§3.2）。**Rust 侧只有这一处改动，typst 与 fast_press 一行不动** |
| 删 | `templates/minimal_card.dart`、`note_card.dart`、复制文本 |
| 连带 | `mobile/pubspec.yaml` 去掉 `moodiary_share`；`mobile/lib/app/router` 去掉 `shareRoutes()`；`app_lock_observer.dart` 的 `/share` 常量不动 |
| 依赖 | `moodiary_export/pubspec.yaml` 加 `re_highlight: 0.0.3`（与 `moodiary_assistant` 同一钉版本，别漂） |

i18n：`share_{zh,en}.i18n.json` 保留（分享弹窗 + 预览页文案），图片格式的选项文案进 `export_*`。改完必跑 `dart tool/task.dart i18n`。

## 7. 分阶段

| 阶段 | 内容 | 可验证点 |
|---|---|---|
| P0 | `ImageComposer` 离屏管线 spike：一段纯文字 + 一张图 → PNG 落盘 | 真机出图不空白、字体正常 |
| P1 | IR 9 种块的渲染 + 两个模版 + 明暗 + 页脚 | golden 测试（结构级） |
| P2 | 分带算法 + Rust `PngStripeWriter` | 分带纯函数单测；一张 1080×30000 的 PNG 落盘不超内存 |
| P3 | 接进 `ExportService`：`ExportFormat.image` + `_writeImage` + 选项持久化 | `export_options_test.dart` 口径的编解码单测 |
| P4 | 预览页外壳 + 图片/Markdown 两种预览 + 分享底部弹窗 + `FormatExportPage` 吃可选 scope | 单篇链路走通 |
| P4.5 | 图片批量页的「预览样张」（只跑第一篇） | 全量导出前能先看一眼 |
| P5 | 导入导出页图片入口 + 保存到相册 + 多张处理 | 多篇链路走通 |
| P6 | 删 `moodiary_share`、清路由与依赖、`check_layers` 归零 | `dart tool/task.dart analyze` + `test` |

## 8. 风险

1. **离屏管线是全仓第一次用**。`RenderObjectToWidgetAdapter` 在 3.47.2 还在（`widgets/adapter.dart`），但已被标记为 `RootWidget` 的替代品，将来会移除；`implicitView` 在多视图场景可能为 null。P0 先 spike，失败则退回「可见树里挂一个屏幕外的 `Overlay` 条目」——能用，只是批量慢一帧一篇。
2. **内存**。分带把峰值锁在单带 8.6 MB，但批量仍必须串行 + 及时 dispose；解码时降采样（`targetWidth`）是必须的，不是优化。
3. **观感漂移**。编辑器加节点 → 图片渲染器不跟 → `unsupportedNodes` 报出来（已有机制），但用户看到的是「少了一段」。发版前的编辑器节点变更要连带看这里。
4. **本期不碰 Rust 的 typst 那一侧**。slim fork、六个 opt-out feature、18.58 MB 全部保持现状；将来做 PDF 预览时再按 §2.5 的两条路选一条，那时才需要重新算体积账。
5. **相册权限被拒**。`saveToGallery` 现在吞异常只返回 `false`；预览页要把 false 翻成「相册权限被拒绝」而不是笼统的失败。

## 9. 拍板记录（2026-09-04）

| 项 | 结论 |
|---|---|
| `moodiary_share` 怎么摆 | **整包并入 `moodiary_export` 后删除**（§6），按 P6 走 |
| 图片模版 | **只做「原稿」一个**，明暗独立；旧的 minimal / note 退休（§3.3） |
| 代码块语法高亮 | **做**，接 `re_highlight: 0.0.3`，与助手同一张表（§3.3） |
| 分享图里的位置 | **单独开关，默认关**；日期 / 心情 / 天气 / 分类仍跟 `includeMeta`（§4） |
| 「复制文本」 | 删除，不在弹窗里留次要入口 |
| md / docx / pdf 的单篇分享 | 点了就用默认设置生成，直接拉系统分享面板；**没有中间页也没有预览**（§5.1） |
| 长图张数 | 永远一张，高度不设上限；分带只是实现细节（§3.2） |
| md / docx / pdf 的预览 | **本期不做**，方案与成本存档在 §2.5；typst 保持 slim fork 不动 |

| 图片预览页的设置入口 | **不留**。顶栏只有返回键，整页三个可点的东西（§5.2） |

全部拍完，没有悬而未决的项。
