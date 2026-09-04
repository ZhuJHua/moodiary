# moodiary_export

导出四种格式 + 本地备份进出 + **分享**（分享 = scope 只有一篇的导出，`moodiary_share`
2026-09-04 并进来后删除）。设计稿与决策记录在 `docs/image-export.md`。

一条链，四个 writer：`ExportScope → List<Diary> → ExportDoc(IR) → writer`。
md 在 `MarkdownWriter`，docx / pdf 在 `fast_press`，**图片在本包的 `ImageComposer`**。

## 图片导出（`ImageComposer` + `presentation/image_card/`）

- **不截 WebView**：`RenderRepaintBoundary.toImage()` 只光栅化 Flutter 自己的图层树，
  平台视图（Android hybrid/TLHC、iOS `UIKitView`）不在其中，截出来是空白。所以图片这条
  和另外三种一样吃 IR，自己画一棵树。
- **产物永远一张**，高度不设上限。分带只是实现细节：`toImage` 受 GPU 纹理上限约束
  （多数设备 16384，老的 4096），按 2000 逻辑像素一带光栅化，逐带喂 `fast_image` 的
  `FastPngWriter` 流式写进同一个 PNG。整张图的位图在任何一侧都不存在（峰值 ≈ 8.6 MB/带）。
  分带算法是纯函数 `imageBands`，测试钉住三条性质（首尾相接 / 切点是整数 / 至少一带）。
- **离屏管线的四条硬约束**（违反了就是空白图，见 `image_composer.dart` 的 `_Composition`）：
  1. 图片必须**预解码**成 `ui.Image` 再进树 —— 离屏树不跑第二帧，`Image.file` 的异步
     resolve 永远来不及。解码时按目标像素宽 `targetWidth` 降采样。
  2. `TextScaler.noScaling` —— 导出物的字号不跟手机的显示设置走。
  3. 主题是**快照**（`ImageCardStyle`，纯数据）：离屏树里没有祖先 `Theme`，
     由有 context 的那一侧解析好传进来（`ImageCardStyle.resolve`）。
  4. 每带出图后立刻 `dispose`；批量串行，绝不并发。
- 换带只 `markNeedsPaint`（`_RenderBand` 监听一个 `_BandController`），**不重建 widget**：
  树只建一次、文字只排一次版。
- 排版照抄编辑器（正文 16/1.7、标题 22/700、h1 1.7em…），不是 M3 的 15 级 —— 图片要像
  「日记本身」，不像一个 App 页面。字重只能整档换（可变字体下 `copyWith(fontWeight:)`
  会被 `fontVariations` 吃掉），所以 `ImageCardStyle` 备了 `bodyStrong` / `metaStrong`。
- 代码高亮走 `re_highlight`，表在 `moodiary_components` 的 `code_theme.dart`（与助手同一张）。
- 页脚的品牌标识是 `MoodiaryLogo.rasterize`（资源与组件都归 `moodiary_components`）：
  **SVG 必须先转成 `ui.Image`**，离屏树里 `SvgPicture` 的异步加载永远等不到第二帧。

## 两个坑

- **产物在缓存目录，随时会被系统清掉**。实测：导出完 20 秒，磁盘吃紧的 Android 就把整个
  `cache/export/` purge 了，而 Gal 会把「文件不存在」报成 `NOT_SUPPORTED_FORMAT`。
  交付前一律 `File.existsSync()`，缺了就报 `artifactMissing`（`shareExported` 一直是这么做的）。
- **位置默认不出门**：`ExportCommon.includePosition` 默认 false，在 `_toExportDoc` 一处掐掉，
  四种格式一起生效 —— 下游三个 writer 与图片渲染器都只看 `ExportDoc`，不必各自再判一次。

## 分享入口

日记页在 `moodiary_diary`，两个都是 feature **不能互相 import**，所以经
`moodiary_components` 的 `DiaryShare` 挂钩：组合根（`mobile/lib/main.dart`）启动时
`DiaryShare.register(showDiaryShareSheet)`。路由 `/share` 归本包，**路径不能改**
（`app_lock_observer` 按字面量放行它）。
