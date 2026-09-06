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

## Markdown 导出 = 导入规范的产物

不合并模式的 md 导出**就是**下面「Markdown 导入」那套规范的包，能原样导回（含换设备）：
素材按 `assets/<image|video|audio>/` 分目录；**图片原字节照搬、不转 JPEG**（`_MediaStage`
的 `copyOriginals`，docx / pdf 仍转码，那是 docx-rs / typst 的要求，不是 markdown 的）；
front matter 的 `time` 带时区偏移（`toIso8601String` 对本地时间不带，导回来换了时区就漂）。
改布局 / 改键名两边要一起动，`test/import/markdown_front_matter_test.dart` 有往返用例钉着。

## 两个坑

- **产物在缓存目录，随时会被系统清掉**。实测：导出完 20 秒，磁盘吃紧的 Android 就把整个
  `cache/export/` purge 了，而 Gal 会把「文件不存在」报成 `NOT_SUPPORTED_FORMAT`。
  交付前一律 `File.existsSync()`，缺了就报 `artifactMissing`（`shareExported` 一直是这么做的）。
- **位置默认不出门**：`ExportCommon.includePosition` 默认 false，在 `_toExportDoc` 一处掐掉，
  四种格式一起生效 —— 下游三个 writer 与图片渲染器都只看 `ExportDoc`，不必各自再判一次。

## Markdown 导入（`data/import/`）

规范（用户可手工造包，本 App「不合并」导出的 md zip 天然符合）：**zip 顶层的 `*.md` 各一篇**
（子目录里的不算，也接受单个 `.md`）；媒体在 `assets/`（子目录任意）按相对路径引用；
front matter 可选，八个键与 `MarkdownWriter._frontMatter` 逐一对应。缺省推导：标题 ← 正文首个
一级标题（取走）← 文件名；时间 ← 文件名开头 `YYYY-MM-DD` ← 文件 mtime ← 现在。

- **媒体改写必须先于 tiptap 转换**（`ImportMediaStage.rewrite` → `MarkdownToTiptap`）：转换器按
  `image-` / `video-` / `audio-` 前缀把 `![](name)` 分流成一等节点，`withDerivedMedia` 才数得出三列。
  三类统一改写成图片语法。收不进来的图片引用**降级成普通链接**，否则会留下指向不存在文件的
  图片节点、还被数进 `imageName`。
- **媒体一律拷贝重命名**（`reuseExisting: false`），唯一例外：包里的名字已是本 App 形制、
  本机同名文件存在且内容一致（长度 + 头/中/尾各 64 KB 抽样 md5，不算整文件哈希）才复用；视频还要求封面在。
- **`id` 已存在（或本批重复）就跳过**，计入 skipped —— 重复导入自己的导出不翻倍；合法 uuid 沿用，
  否则新 uuid v7。
- 合并模式（一个文件多篇、`---` 分隔）**不支持**：与 front matter / 分割线歧义。`[[双链]]` 保持文本。
- 地点复用顺序：同名 → 200 m 内最近 → `Place.forName` 新建（跨设备同名合并）；分类按名精确匹配。
- 攒 100 篇一批 `insertDiaries`，`fromSync: false`（本机新增要推同步）；取消也把已转换的落库
  （媒体已经拷进来了，丢掉只留孤儿文件），报告标 `cancelled`，页面不得按成功呈现。
- 工作目录在 `cache/import/<stamp>/`，zip slip 由 fast_zip 的 `enclosed_name()` 挡；「压缩文件夹」
  多套的一层目录（含 `__MACOSX/`）会自动往下走一层。

## 分享入口

日记页在 `moodiary_diary`，两个都是 feature **不能互相 import**，所以经
`moodiary_components` 的 `DiaryShare` 挂钩：组合根（`mobile/lib/main.dart`）启动时
`DiaryShare.register(showDiaryShareSheet)`。路由 `/share` 归本包，**路径不能改**
（`app_lock_observer` 按字面量放行它）。
