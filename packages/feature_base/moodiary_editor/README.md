# moodiary_editor

可嵌入的日记编辑器包：webview 里的 TipTap 编辑器组件 + 无头 markdown→JSON 转换服务。

## 对外 API（`package:moodiary_editor/moodiary_editor.dart`）

- `MoodiaryEditor` / `MoodiaryEditorController` —— 嵌入式编辑器组件（仅渲染正文）。
- `EditorConversionService` —— 无头 markdown→TipTap JSON 转换（迁移工具 / AI 助手用）。
- `EditorLocalServer`、`MediaResolver`、`imageMimeOf`/`audioMimeOf`/`videoMimeOf` —— 本地回环服务（支持 HTTP Range）与媒体解析注入点。

## 与宿主 app 解耦（注入式）

`MoodiaryEditor` 不依赖 app 代码，宿主通过参数注入：
- `seedResolver` —— 实时返回主题种子（`({Color seed, String variant})`）；明暗由 `Theme.of(context)` 推断。
- `mediaResolver` —— 媒体文件名 → 磁盘路径 + MIME，注入给 `EditorLocalServer` 按需读盘。
- `loadingBuilder` —— 加载遮罩（不传则用 `CircularProgressIndicator`）。
- `onPickImage/onPickAudio/onPickVideo/onSaveImage/onImageTap` —— 媒体选取/存盘/点击回调（音视频在 webview 内用原生 `<audio>`/`<video>` + daisyUI 自绘控件内联播放，无需播放回调）。

## Web 源与构建

- web 源在 `editor/`（Vue 3 + Vite + TipTap）；`pnpm build` 经 `vite-plugin-singlefile` 输出**单文件** `../assets/editor/index.html`（gitignored）。
- 仓库根用 `dart tool/task.dart editor` 一键构建；CI 在 `flutter build` 前需先构建。
- 开发预览：`cd editor && pnpm harness`。
