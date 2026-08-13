# CLAUDE.md

## Project Overview

Moodiary — a Flutter + Rust diary app. **Layered pub-workspace monorepo**: 18 shared packages under `packages/` across four dependency layers, consumed by the single Flutter app **`mobile/`** (Android + iOS, pub name `moodiary`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code). A desktop app will be rebuilt later — the packages are already layered for it, but no desktop target exists in the tree today.

## Tech Stack

- **Flutter 3.47.0 / Dart 3.13.0** (FVM, `.fvmrc`)
- **Rust** (pinned in `packages/foundation/moodiary_rust/rust/rust-toolchain.toml`), `flutter_rust_bridge` 2.13.0-beta.6 — native lib built & bundled via Native Assets build hooks (`rustup` required)
- **Android**: AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.0，内置 Kotlin（`android.builtInKotlin=true`）；daemon JVM 由 `gradle-daemon-jvm.properties` 钉在 21
- **Riverpod** (dev) + code gen, **go_router**, **get_it**, **Isar**, **Freezed** + **json_serializable**

## Commands

```bash
# Setup
fvm use
dart tool/task.dart setup          # flutter pub get + build editor

# Run & Build (targets mobile app)
dart tool/task.dart run            # build editor + flutter run
dart tool/task.dart build-apk / build-ios  # 只有 android/ios 两个目标
# Extra flutter flags go after --:  dart tool/task.dart run -- --release

# Code Gen (after model/router/provider changes)
dart tool/task.dart build-runner   # build_runner build（2.16.0 起 --delete-conflicting-outputs 已移除）
dart tool/task.dart gen-rust       # regenerate Rust FFI bindings
dart tool/task.dart gen            # gen-rust + rebuild editor asset
dart tool/task.dart editor         # rebuild editor asset only (needs corepack on PATH)

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # mobile/ tests ONLY — not the full suite
melos exec --dir-exists=test --fail-fast -c 1 -- flutter test   # 全仓 Dart 测试（CI 口径，自动发现）
cd packages/foundation/moodiary_rust/rust && cargo test --workspace && cargo clippy --workspace --all-targets -- -D warnings
cd packages/feature/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test
```

Full-repo verification = the four blocks above (analyze + layers, melos test sweep, Rust, editor). `flutter test` at the repo root finds nothing.

**Melos**: `melos bootstrap` activates the workspace and regenerates IDE module files — pure, no codegen; run `dart tool/task.dart gen` separately. `melos list` / `melos run <script> --category <layer>` filter by layer.

**Versions** are exact-pinned everywhere; the root `melos` caret is the only exception.

## Architecture

### Directory Layout

```
moodiary/                    # root = workspace + Melos coordinator (no app code)
  tool/                      # cross-platform task runner + layer check
  mobile/                    # pure-mobile Flutter app (pub: moodiary)
    lib/
      app/                   # composition layer: di, router, shell, lifecycle
        home/                # home tab (diary_home_page)
        settings/            # settings hub
      main.dart
  packages/
    foundation/              # leaf layer — no internal deps
      moodiary_lint/         #   shared analyzer options
      moodiary_l10n/         #   localization (ARB + gen-l10n)
      moodiary_router/       #   typed route primitives over go_router
      moodiary_rust/         #   Rust FFI package (cargo workspace in rust/, built by hook/build.dart)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
    core/                    # → foundation; internal order models → core → data,migration → preferences
      moodiary_models/       #   domain: Isar @Collection + Freezed DTOs
      moodiary_core/         #   infra: Isar/KV/SecureKV + theme + exceptions
      moodiary_data/         #   repositories + controllers + 跨 feature 共享的进程级瞬态状态
      moodiary_migration/    #   one-shot legacy data migration
      moodiary_preferences/  #   preference state
    ui/                      # → core/foundation
      moodiary_ui/           #   business-agnostic reusable widgets
    feature/                 # → ui/core/foundation (features never import each other)
      moodiary_editor/       #   TipTap webview editor (complete)
      moodiary_diary/        #   diary CRUD/search/category/calendar/map/recycle
      moodiary_sync/         #   sync engine + UI
      moodiary_assistant/    #   AI assistant (flutter_chat_ui + rig)
      moodiary_media/        #   media library
      moodiary_lock/         #   app lock
      moodiary_share/        #   diary sharing
```

Path convention: unqualified `lib/...` refers to `mobile/lib/...`; `packages/` and `tool/` are repo-root-relative.

### Layer Dependencies

Cross-package DAG is strictly upper → lower: `foundation → core → ui → feature → apps`. Features never import each other (the one kept exception is `diary → editor`); shared logic sinks to lower layers, cross-feature composition happens in the app layer. pub only guarantees acyclicity, so **direction is enforced by `tool/check_layers.dart`**, which reads every pubspec's `moodiary_*` deps (no baseline — must stay at zero). Melos `categories:` are filter/grouping only.

In-app layering within `mobile/lib` (same script): `gen → core → data → component → feature/<x> → app → main.dart`. Baseline is **zero violations**.

### Rust Workspace

`packages/foundation/moodiary_rust/rust/` is both the cargo workspace root **and** the bridge package `moodiary_rust` — that shape is load-bearing: the Native Assets hook runs `cargo build --manifest-path rust/Cargo.toml --package moodiary_rust` and requires `Cargo.toml` + `rust-toolchain.toml` at `hook/build.dart`'s `cratePath`, so keeping `rust/` as the root means the hook and `flutter_rust_bridge.yaml` need no changes.

```
rust/
  src/api/            # bridge = app layer: the ONLY place that knows about FRB
  crates/
    foundation/       # http (reqwest client + hyper server) / crypto / archive / media / text / font
    core/             # doc (导出 IR，Dart export_doc.dart 的镜像)
    feature/          # sync (s3+webdav) / export (pdf+docx) / assistant (rig) / graph
```

Same direction rule as Dart, enforced by the same script: `foundation → core → feature → bridge`, features never import each other, zero violations.

Two invariants worth keeping:
- **Sub-crates never mention `StreamSink` / `DartFnFuture`.** They take plain closures (`impl FnMut(T) -> bool`, `Arc<dyn Fn(..) -> BoxFuture<..>>`); `src/api/` adapts those to FRB.
- **FFI-visible types are declared in the sub-crate and re-exposed via `#[frb(mirror(T))]` in `src/api/`.** Mirror emits identical Dart to a local declaration, so no DTO is duplicated and no `From` conversion is needed. Opaque handles (`S3Client`, `Zip`, …) are thin newtypes in `src/api/` that delegate.

All third-party versions are exact-pinned (`=x.y.z`) in `[workspace.dependencies]`; sub-crates use `{ workspace = true }` and add only the features they need.

