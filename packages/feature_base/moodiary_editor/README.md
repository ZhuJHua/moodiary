# moodiary_editor

可嵌入的日记编辑器包：webview 里的 TipTap 编辑器组件 + 旧格式日记的无头迁移服务。

## 对外 API（`package:moodiary_editor/moodiary_editor.dart`）

- `MoodiaryEditor` / `MoodiaryEditorController` —— 嵌入式编辑器组件（标题 + 属性头 + 正文）。
- `EditorMigrationService` —— 旧格式日记（Quill / Markdown）无头转 TipTap JSON（迁移页用）。
- `EditorLocalServer`、`MediaResolver`、`imageMimeOf`/`audioMimeOf`/`videoMimeOf` —— 本地回环服务（支持 HTTP Range）与媒体解析注入点。

## 与宿主 app 解耦（注入式）

`MoodiaryEditor` 不依赖 app 代码，宿主通过参数注入：
- `rolesResolver` —— 按 `Brightness` 返回编辑器角色色表 `EditorRoles`（`Map<String, String>`）。
- `mediaResolver` —— 媒体文件名 → 磁盘路径 + MIME，注入给 `EditorLocalServer` 按需读盘。
- `loadingBuilder` —— 加载遮罩（不传则用 `CircularProgressIndicator`）。
- `onPickImage/onPickAudio/onPickVideo/onSaveImage/onImageTap` —— 媒体选取/存盘/点击回调（音视频在 webview 内用原生 `<audio>`/`<video>` + daisyUI 自绘控件内联播放，无需播放回调）。

## Web 源与构建

- web 源在 `editor/`（Vue 3 + Vite + TipTap）。`hook/build.dart` 在 `flutter run` / `build` 时构建（目标系统等于宿主时直接返回，`flutter test` 不构建），输出平铺的 gzip 产物到 `../assets/editor/`，运行时由 `EditorLocalServer` 解压后发明文。钩子声明 `editor/src/**` 与配置文件为依赖，改了源码自动重建，要求 `corepack` 在 PATH 上。
- 页面文案是仓库根的 `i18n/web/{zh,en}.json`（slang 不读这里，两边都要的串各存一份）：由 `@intlify/unplugin-vue-i18n` 的 `include` 预编译进产物，运行时交给 vue-i18n，无需额外 codegen；boot 只下发 `locale`，钩子把该目录也声明为依赖。
- 开发预览：`cd editor && corepack pnpm harness`。
