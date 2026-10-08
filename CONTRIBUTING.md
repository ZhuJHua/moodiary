# Contributing to Moodiary

<p><a href="CONTRIBUTING.zh.md">简体中文</a> | English</p>

Thanks for helping out. Bug reports, feature ideas, translations and code are all welcome.

## Before you start

- **Bugs and ideas**: open an issue with one of the [templates](https://github.com/ZhuJHua/moodiary/issues/new/choose). Search first; a 👍 on an existing issue helps more than a duplicate.
- **Code**: small fixes can go straight to a PR. For a new feature or a large refactor, open an issue first so we agree on the direction before you spend the time.
- **Branch**: fork the repo and branch from `develop`. PRs target `develop`; `main` only receives releases.
- **License**: Moodiary is [AGPL-3.0](LICENSE). By submitting a PR you agree your contribution is licensed under it.

## Development setup

| Tool | Version | Notes |
|---|---|---|
| Flutter | 3.47.2 | pinned in `.fvmrc`; [FVM](https://fvm.app) recommended |
| Melos | 8.6.0 | pinned in the root `pubspec.yaml`; `dart pub global activate melos 8.6.0` |
| Rust | via `rustup` | each native package pins its toolchain in `rust-toolchain.toml` |
| cargo-about | 0.9.2 | `cargo install cargo-about --version 0.9.2 --locked`; builds the license page |
| Node.js + Corepack | Node 20.19+ or 22.12+ | builds the web editor bundle; `corepack enable` |
| Android | JDK 21, NDK 28.2.13676358 | |
| iOS | Xcode with iOS 16.4+ SDK | set your own signing team in Xcode |

```bash
fvm use
melos bootstrap
dart tool/task.dart setup
dart tool/task.dart run            # extra flutter flags go after --, e.g. -- --release
```

Native libraries and the editor bundle are built by build hooks on the first run, so it takes a while. If a build behaves as if your changes were not picked up, `dart tool/task.dart clean` clears the hook caches.

## Project layout

Moodiary is a pub-workspace monorepo: one Flutter app in `mobile/` and shared packages under `packages/`, in four layers:

```
foundation  ->  core  ->  feature_base  ->  feature  ->  mobile/
```

- A package may only depend on layers to its left. Features never import each other; shared logic moves down a layer. `tool/check_layers.dart` enforces this.
- Business code imports `package:mui/mui.dart`, never `package:flutter/material.dart` directly.
- Translations live in `i18n/flutter` (app, slang) and `i18n/web` (editor page). Add every new string in both `zh` and `en`.
- Dependency versions are pinned exactly, no `^`.

[`CLAUDE.md`](CLAUDE.md) is the detailed architecture reference (DI, routing, i18n, Rust packages, search); read the relevant section before touching an area.

## Code generation

Generated files are committed. Re-run the matching task after editing its source:

| You changed | Run |
|---|---|
| Freezed / json / Riverpod / injectable / drift sources | `dart tool/task.dart build-runner` |
| `rust/src/api` in a native package | `dart tool/task.dart gen-rust` |
| `i18n/flutter/*.i18n.json` | `dart tool/task.dart i18n` |
| drift `schemaVersion` | `dart tool/task.dart migrations` |

## Before you open a PR

Run the checks that cover what you touched. CI runs the same ones and all must pass:

```bash
dart tool/task.dart analyze        # layer check + flutter analyze
dart tool/task.dart test           # tests for the packages your branch affects

# Rust, if you touched packages/foundation/*/rust
for d in packages/foundation/*/rust; do (cd $d && cargo clippy --all-targets -- -D warnings && cargo test); done

# Editor, if you touched packages/feature_base/moodiary_editor/editor or i18n/web
cd packages/feature_base/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test
```

Format Dart with `dart format`. For UI changes, try them on a device or emulator and attach screenshots.

## Pull requests

PRs are squash-merged: the **PR title becomes the commit subject** and the **PR description becomes the commit body**. Both are in English.

### Title: Conventional Commits

The title follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). The `PR title` check fails until it does, and labels the PR by type.

```
<type>[(scope)][!]: <description>
```

| Part | Rule |
|---|---|
| `type` | lowercase, one of the table below |
| `scope` | optional, lowercase, the feature or package: `diary`, `sync`, `editor`, `moodiary_data`, `i18n/web`, … |
| `!` | optional, marks a breaking change |
| `description` | after `: `, imperative mood, no trailing period: `add`, not `added` / `adds` |

| Type | For | Changelog section |
|---|---|---|
| `feat` | a new user-facing feature | Features |
| `fix` | a bug fix | Bug Fixes |
| `perf` | a performance improvement | Performance |
| `refactor` | code change that neither fixes a bug nor adds a feature | Refactor |
| `docs` | documentation only | Documentation |
| `test` | tests only | Testing |
| `style` | formatting, no behaviour change | Styling |
| `build` | build system, hooks, toolchains | Miscellaneous |
| `ci` | CI workflows | Miscellaneous |
| `chore` | anything else that ships no code | Miscellaneous |
| `revert` | reverting an earlier commit | Revert |

```
feat(diary): add a year view to the calendar
fix(sync): degrade when the remote rejects a conditional write
refactor(rag)!: move the sqlite-vec binding into its own package
```

GitHub's Revert button produces `Revert "…"`, which the check rejects; rename it to `revert: <original subject>` and put `Refs: <sha>` in the description.

### Description: body and footers

Write what changed, why, and how you tested it, following the PR template; delete the sections that don't apply. Footers are lines of the form `Token: value` (or `Token #value`) separated from the text above by a blank line, and are read from the squash commit:

| Footer | Effect |
|---|---|
| `BREAKING CHANGE: <what breaks and how to migrate>` | marks the PR as breaking; use it alone or together with `!` in the title |
| `Changelog: skip` | keeps the PR out of `CHANGELOG.md` |
| `Closes #123` | closes the issue on merge |

A breaking change is anything that stops existing data, backups, sync remotes or LAN peers from working without a migration, or removes a user-facing feature. Breaking PRs get a `breaking` label and always appear in the changelog, even under a skipped scope.

Scopes skipped by the changelog: `chore(deps)`, `chore(readme)`, `chore(pr)`, `chore(pull)`, `chore(release)`.

### Scope of a PR

- **One topic per PR.** Unrelated refactors or formatting sweeps make review slow; send them separately.
- **Data formats.** Changes to the database schema, sync layout or LAN protocol need a migration path and must be called out in the description.

Releases are cut by the maintainer; don't bump versions or edit `CHANGELOG.md` in a PR.

## Community

Questions and discussion: [Forum](https://answer.moodiary.net) · Telegram [openmoodiary](https://t.me/openmoodiary) · QQ group 760014526.
