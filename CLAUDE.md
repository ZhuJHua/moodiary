# CLAUDE.md

## Project Overview

Moodiary — a Flutter + Rust diary app (Android, iOS, Windows, macOS). **Layered pub-workspace monorepo**: ~18 shared packages under `packages/` across four dependency layers, consumed by two Flutter apps: **`mobile/`** (pure mobile, pub name `moodiary`) and **`desktop/`** (desktop skeleton, pub name `moodiary_desktop`). The root `pubspec.yaml` is a pure coordinator (workspace + Melos config, no app code).

## Tech Stack

- **Flutter 3.44.0** (FVM, `.fvmrc`)
- **Rust** (pinned in `packages/foundation/moodiary_rust/rust/rust-toolchain.toml`), `flutter_rust_bridge` 2.13.0-beta.5 — native lib built & bundled via Native Assets build hooks (`rustup` required)
- **Riverpod** (dev) + code gen, **go_router**, **get_it**, **Isar**, **Freezed** + **json_serializable**

## Commands

```bash
# Setup
fvm use
dart tool/task.dart setup          # flutter pub get + build editor

# Run & Build (targets mobile app)
dart tool/task.dart run            # build editor + flutter run
dart tool/task.dart build-apk / build-ios / build-windows / build-macos
# Pass extra flutter flags after --:  dart tool/task.dart run -- --release
# Desktop app (not yet wired into task.dart): cd desktop && fvm flutter run -d macos

# Code Gen (after model/router/provider changes)
dart tool/task.dart build-runner   # build_runner build --delete-conflicting-outputs
dart tool/task.dart gen-rust       # regenerate Rust FFI bindings (cd packages/foundation/moodiary_rust && frb generate)
dart tool/task.dart gen            # gen-rust + rebuild editor asset

# Editor rebuild
dart tool/task.dart editor         # cd packages/feature/moodiary_editor/editor && pnpm install && pnpm build

# Lint & Test
dart tool/task.dart analyze        # layer check + flutter analyze
fvm flutter test
```

**Melos**: `melos bootstrap` activates the workspace and regenerates IDE module files (pure — no codegen; run `melos gen` / `dart tool/task.dart gen` separately for Rust bindings + editor asset). `melos list` / `melos run <script> --category <layer>` filter by layer. Melos CLI is a root dev_dependency (version conflict with `cli_util` requires `dependency_overrides: cli_util: 0.5.0`). The editor build needs `corepack` on PATH (`npm i -g corepack` / `brew install corepack`).

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
      merge/                 # one-shot legacy data migration (flutter_quill holdout)
      main.dart
  desktop/                   # desktop Flutter app skeleton (pub: moodiary_desktop)
  packages/
    foundation/              # leaf layer — no internal deps
      moodiary_lint/         #   shared analyzer options
      moodiary_l10n/         #   localization (ARB + gen-l10n)
      moodiary_rust/         #   Rust FFI package (crate in rust/, built by hook/build.dart)
      moodiary_utils/        #   pure utils + content converters (tiptap/markdown/quill)
    core/                    # → foundation; internal order models → core → data → preferences
      moodiary_models/       #   domain: Isar @Collection + Freezed DTOs
      moodiary_core/         #   infra: Isar/KV/SecureKV + theme + exceptions
      moodiary_data/         #   repositories + controllers
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
      moodiary_scan/         #   encrypted QR
      moodiary_share/        #   diary sharing
```

Path convention: unqualified `lib/...` refers to `mobile/lib/...`; `packages/`, `tool/`, `desktop/` are repo-root-relative.

### Layer Dependencies

Cross-package DAG is strictly upper → lower: `foundation → core → ui → feature → apps`. Features never import each other (shared logic sinks to lower layers, cross-feature composition happens in the app layer). Enforced by pub's acyclic graph; Melos `categories:` are filter/grouping only.

In-app layering within `mobile/lib` (`tool/check_layers.dart`): `gen → core → data → component,merge → feature/<x> → app → main.dart`. Baseline is **zero violations**.

