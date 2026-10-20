# moodiary_editor

Moodiary's embedded TipTap webview editor and headless migration service for legacy diary formats.

## Public API

Import `package:moodiary_editor/moodiary_editor.dart`:

- `MoodiaryEditor` / `MoodiaryEditorController`: the embedded editor, including the title, metadata header and document body.
- `EditorMigrationService`: converts legacy Quill and Markdown entries to TipTap JSON without a webview.
- `EditorLocalServer`, `MediaResolver`, `imageMimeOf` / `audioMimeOf` / `videoMimeOf`: the loopback server with HTTP Range support and media resolution interfaces.

## Host integration

The package does not import application code from `mobile/`. The host mounts its injectable micro-module, and `MoodiaryEditor` resolves `EditorLocalServer` through `getIt`. The widget accepts:

- `rolesResolver`: maps `Brightness` to an `EditorRoles` color map (`Map<String, String>`).
- `mediaResolver`: resolves media filenames to local paths and MIME types for the server to read on demand.
- `loadingBuilder`: customizes the loading overlay; the default is `CircularProgressIndicator`.
- `onPickImage` / `onPickAudio` / `onPickVideo` / `onSaveImage` / `onImageTap`: media selection, storage and image preview callbacks. Inline audio and video use HTML media elements with custom controls; `onVideoFullscreen` delegates fullscreen playback to the host.

## Web sources and builds

- Web sources live in [`editor/`](editor/) and use Vue, Vite and TipTap. [`hook/build.dart`](hook/build.dart) installs locked dependencies and builds during Flutter run/build; host-target code-asset builds, including Flutter tests, skip this step. It tracks web sources and configuration files for rebuilds and requires `corepack` on `PATH`. Use the Node.js and pnpm versions declared in `editor/package.json`.
- Vite writes flat gzip assets to `assets/editor/`. `EditorLocalServer` decompresses them before serving them to the webview.
- Web translations live in the repository's [`i18n/web/`](../../../i18n/web/) directory. `@intlify/unplugin-vue-i18n` compiles them into the bundle for vue-i18n; the Flutter bridge supplies the locale at boot. The build hook also tracks this directory. These strings do not use slang code generation; wording shared with Flutter must be maintained in both translation trees.
- Development preview: from this package, run `cd editor && corepack pnpm install --frozen-lockfile && corepack pnpm harness`.
