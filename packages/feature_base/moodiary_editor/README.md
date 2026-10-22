# moodiary_editor

Moodiary's embedded Tiptap 3 editor, native Flutter toolbar and headless migration service for legacy diary formats.

## Public API

Import `package:moodiary_editor/moodiary_editor.dart`:

- `MoodiaryEditor` / `MoodiaryEditorController`: the embedded editor, including the title, metadata header and document body.
- `EditorMigrationService`: converts legacy Quill and Markdown entries to Tiptap JSON without a webview.
- `MediaResolver`, `imageMimeOf` / `audioMimeOf` / `videoMimeOf`: media resolution interfaces.
- `EditorCommand` / `EditorState`: commands sent to the web editor and selection state received by the native toolbar.

## Host integration

The package does not import application code from `mobile/`. The host mounts its injectable micro-module. `MoodiaryEditor` accepts:

- `rolesResolver`: maps `Brightness` to an `EditorRoles` color map (`Map<String, String>`).
- `fontResolver`: resolves the editor font family and local font file.
- `mediaResolver`: resolves media filenames to local paths; the page requests them over the bridge and loads `file://` URLs.
- `onSaveImage` / `onImageTap` / `onAttachmentTap`: media storage, image preview and attachment callbacks. Inline audio and video use HTML media elements with custom controls; `onVideoFullscreen` delegates fullscreen playback to the host.
- Metadata and diary-link callbacks for host-owned pickers, lookup and navigation.

The toolbar and panels are Flutter widgets. They send `exec(command, args)` over the bridge, and the page reports `EditorState` once per frame. Native keyboard and selection APIs live in `moodiary_native` and are generated with Pigeon.

## Document extensions

Dividers extend Tiptap's `HorizontalRule`, retaining its standard command and Markdown handling. Their `variant` and `label` attributes round-trip through JSON and HTML; Markdown exports them as a standard `---` separator. Media and attachments are block atoms, while diary links extend `Mention` as inline atoms. Node views provide the interactive UI; `parseHTML` and `renderHTML` define clipboard serialization independently of those views.

## Web sources and builds

- Web sources live in [`editor/`](editor/) and use React 19, Vite and Tiptap 3. `core/bridge` owns messaging, boot, theme and debounced changes; `core/editor` owns schema v2, normalization, commands, state, Markdown shortcuts and search; `ui` owns React node views, metadata and overlays. Styles live in `src/styles/`; font sizes use the `--md-text-*` tokens and follow system scaling.
- Content is normalized from v1 to v2 using the same rules as Dart, then loaded with content validation. Invalid JSON, unknown nodes, invalid structure or a newer schema produce `contentError` and a read-only view that never emits `change`.
- [`hook/build.dart`](hook/build.dart) installs locked dependencies and builds during Flutter run/build. Host-target builds, including Flutter tests, skip this step. `vite-plugin-singlefile` writes `assets/editor/index.html` with JavaScript, CSS and fonts inlined. The hook tracks web sources, configuration and translations; it requires `corepack` on `PATH`. Use the Node.js and pnpm versions declared in `editor/package.json`.
- The page loads through `file://`, without a local HTTP server. Android reads it from the APK; iOS copies it into Application Support and grants WebKit read access to the containing directory. Boot data arrives over the bridge after page load. Media and font URLs must not carry query parameters because iOS treats them as part of the filename.
- Web translations live in the repository's [`i18n/web/`](../../../i18n/web/) directory and are bundled as-is. The Flutter bridge supplies the locale at boot. These strings do not use slang code generation; wording shared with Flutter must be maintained in both translation trees.
- Verification: from `editor/`, run `corepack pnpm install --frozen-lockfile`, `corepack pnpm type-check` and `corepack pnpm test`. Tests use Vitest, jsdom and real editor instances with React node views. `corepack pnpm dev` starts the Vite development server.
