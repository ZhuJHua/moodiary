# fast_press

导出压印：把导出 IR（`IrDoc`，Dart 侧 `ExportDoc` 的镜像）压成 PDF（typst 排版）或 DOCX（docx-rs）。
自带 FRB（`flutter_rust_bridge.yaml`，入口类 `FastPressLib`）与原生库 **libfastpress**
（`rust/`，单 crate：`api/` 是 FRB 门面、唯一认识 `flutter_rust_bridge` 的地方；`ir.rs` /
`pdf.rs` / `docx.rs` 是引擎，只收纯闭包）。2026-09-03 从 moodiary_rust 的 `doc` + `export`
两个 crate 与 `export.dart` 门面拆出来，与 fast_image 同一套形状。

- **foundation 叶子包，零 `moodiary_*` 依赖，只有 `moodiary_export` 能依赖它**
  （`tool/check_layers.dart` 的 `_nativePkgOwners`，接替原来 moodiary_rust 的 export 门面）。
- **延迟装载**：没有启动 init。导出服务的 `run` 与导出页构造 `CancelToken()` 之前都先
  `await FastPress.ensureInitialized()`——`CancelToken()` 是同步构造，库没装载就抛。
- **`CancelToken` 是这个库自己的**：FRB 不透明句柄跨不了 .so，与其他 fast_* 的同名类型互不
  相通。导出服务 Dart 侧的轮询（含 zip 打包那段）也只读它，所以 moodiary_export 只拿这一枚。
  只在循环边界生效——typst 整篇排版会跑完当前这一趟。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**（三个 FRB 包都会重生成；`IrBlock`
  的 freezed 产物 codegen 自己跑）；改了 `rust/Cargo.toml` 依赖必跑 `dart tool/task.dart licenses`。
  `IrRow` 包一层具名结构而不是 `Vec<Vec<IrCell>>`：`full_dep: true` 的 CST 编解码器生成嵌套
  列表时会漏掉内层的 fill 函数。
- **PDF 安全要点**（`pdf.rs` 文件头有全文）：生成的是 typst 代码模式，用户文本一律进字符串字面量，
  **任何用户文本都不得进 `[...]` 内容块**。选 typst 不选 Dart `pdf` 包是因为后者对中文长文是
  二次方的（32 万字外推 8 小时 vs typst 0.29 秒）。
- **docx-rs 两个坑**（`docx.rs` 文件头）：只用 `Pic::new_with_dimensions`（`Pic::new` 四个
  `expect()`，一张坏图整次导出 panic）；zipper 把媒体一律写成 `.png` 部件名，Word / WPS 按内容嗅探。
- 依赖收窄的实测结论（2026-08-20，别再重推）：`image` 七个 feature 里只有 `ico` 是「只有我们开」
  的，其余六个 docx-rs / typst-library 已经各自开着；`syntect` 四个 feature 全与 typst-library
  重合；`two-face` 不是我们的直接依赖（typst-library 钉 0.4.3，升 0.5 图里会出两份）。
- 体积：typst 是这个库的大头（原来占 libmoodiary_rust 六成，`opt-level` 档位实测 38.86 / 18.51 MiB）。
  拆库本身不省体积——每个 Android cdylib 约 300 KB 固定地板，它是投递策略。
- 测试字体用仓内 `packages/foundation/mui/assets/fonts/Dosis.ttf`（相对 crate 根 `../../mui/…`，
  不用系统字体：macOS 的中日韩字体都是 .ttc，CI 上更没有）。
