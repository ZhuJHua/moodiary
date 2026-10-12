# moodiary_editor

可嵌入的日记编辑器包：webview 里的 TipTap 编辑器组件 + 旧格式日记的无头迁移服务。

## 对外 API（`package:moodiary_editor/moodiary_editor.dart`）

- `MoodiaryEditor` / `MoodiaryEditorController` —— 嵌入式编辑器组件（标题 + 属性头 + 正文）。
- `EditorMigrationService` —— 旧格式日记（Quill / Markdown）无头转 TipTap JSON（迁移页用）。
- `MediaResolver`、`imageMimeOf`/`audioMimeOf`/`videoMimeOf` —— 媒体解析注入点。

## 与宿主 app 解耦（注入式）

`MoodiaryEditor` 不依赖 app 代码，宿主通过参数注入：
- `rolesResolver` —— 按 `Brightness` 返回编辑器角色色表 `EditorRoles`（`Map<String, String>`）。
- `mediaResolver` —— 媒体文件名 → 磁盘路径；页面经桥批量请求，拿到 `file://` 地址直接加载（缩略图可在此现生成）。
- `onPickImage/onPickAudioFile/onRecordAudio/onPickVideo/onSaveImage/onImageTap` —— 媒体选取/存盘/点击回调（音视频在 webview 内用原生 `<audio>`/`<video>` + 自绘控件内联播放，无需播放回调）。

## Web 源与构建

- web 源在 `editor/`（React 19 + @tiptap/react + shadcn-ui + Tailwind v4 + Vite）。`hook/build.dart` 在 `flutter run` / `build` 时构建（目标系统等于宿主时直接返回，`flutter test` 不构建），用 `vite-plugin-singlefile` 输出单个 `../assets/editor/index.html`（JS、CSS、字体全内联）。钩子声明 `editor/src/**` 与配置文件为依赖，改了源码自动重建，要求 `corepack` 在 PATH 上。
- 不走本地 HTTP 服务，页面经 `file://` 加载（`lib/src/editor_page.dart`）：安卓直接从 APK 读；WebKit 只给一个目录签读权限，所以 iOS 按内容把页面拷进 Application Support，再授权该目录（媒体、缩略图、字体都在下面）。`file://` 页面不能带参数，boot 由页面加载后经桥向 Flutter 请求；媒体与字体地址不能带 query（iOS 会当成文件名）。
- `editor/src` 分四层，只能向下依赖（`src/layers.test.ts` 强制）：`lib`（store、cn）→ `core`（bridge 协议、TipTap 扩展与 `createEditorKit`、store、i18n，不 import 任何 React 组件）→ `ui`（节点视图、属性头、工具栏等共享 React 件）→ `shell`（`EditorShell` 组装页面、决定工具栏位置与键盘策略）。节点视图经 `createEditorKit({ nodeViews })` 由壳注入。
- 页面文案是仓库根的 `i18n/web/{zh,en}.json`（slang 不读这里，两边都要的串各存一份）：由 `editor/src/i18n` 的类型化 `t()` 直接 import 进产物，无需额外 codegen；boot 只下发 `locale`，钩子把该目录也声明为依赖。
