# 参与贡献 Moodiary

<p>简体中文 | <a href="CONTRIBUTING.md">English</a></p>

感谢你愿意参与。问题反馈、功能建议、翻译和代码都欢迎。

## 开始之前

- **问题与建议**：用 [Issue 模板](https://github.com/ZhuJHua/moodiary/issues/new/choose) 提交。先搜一下，给已有 issue 点 👍 比重复提交更有用。
- **代码**：小修复可以直接提 PR。新功能或大重构请先开 issue，方向达成一致再动手，免得白费功夫。
- **分支**：fork 仓库后从 `develop` 拉分支，PR 也提到 `develop`；`main` 只接收发版。
- **许可**：Moodiary 采用 [AGPL-3.0](LICENSE)，提交 PR 即表示你同意以该协议授权你的贡献。

## 开发环境

| 工具 | 版本 | 说明 |
|---|---|---|
| Flutter | 3.47.2 | 钉在 `.fvmrc`，推荐用 [FVM](https://fvm.app) |
| Melos | 8.6.0 | 钉在根 `pubspec.yaml`；`dart pub global activate melos 8.6.0` |
| Rust | 通过 `rustup` | 各原生包的 `rust-toolchain.toml` 自带工具链版本 |
| cargo-about | 0.9.2 | `cargo install cargo-about --version 0.9.2 --locked`，用于生成开源许可页 |
| Node.js + Corepack | Node 20.19+ 或 22.12+ | 构建网页编辑器产物；`corepack enable` |
| Android | JDK 21、NDK 28.2.13676358 | |
| iOS | 带 iOS 16.4+ SDK 的 Xcode | 在 Xcode 里换成你自己的签名团队 |

```bash
fvm use
melos bootstrap
dart tool/task.dart setup
dart tool/task.dart run            # 额外的 flutter 参数放在 -- 之后，如 -- --release
```

原生库和编辑器产物由 build hook 在首次运行时构建，第一次会比较慢。如果改动像是没生效，`dart tool/task.dart clean` 会清掉 hook 缓存。

## 项目结构

Moodiary 是 pub workspace monorepo：`mobile/` 是唯一的 Flutter 应用，共享包在 `packages/` 下，分四层：

```
foundation  ->  core  ->  feature_base  ->  feature  ->  mobile/
```

- 包只能依赖左边的层。feature 之间互不导入，共享逻辑下沉一层。由 `tool/check_layers.dart` 检查。
- 业务代码导入 `package:mui/mui.dart`，不直接导入 `package:flutter/material.dart`。
- 翻译在 `i18n/flutter`（App，slang）和 `i18n/web`（编辑器页面）。新增文案 `zh` 和 `en` 都要写。
- 依赖版本精确钉死，不用 `^`。

详细架构说明（DI、路由、i18n、Rust 包、搜索）见 [`CLAUDE.md`](CLAUDE.md)，改动某块前先读对应章节。

## 代码生成

生成文件会提交进仓库。改了源文件后跑对应任务：

| 改了什么 | 运行 |
|---|---|
| Freezed / json / Riverpod / injectable / drift 源文件 | `dart tool/task.dart build-runner` |
| 原生包的 `rust/src/api` | `dart tool/task.dart gen-rust` |
| `i18n/flutter/*.i18n.json` | `dart tool/task.dart i18n` |
| drift 的 `schemaVersion` | `dart tool/task.dart migrations` |

## 提 PR 之前

跑覆盖你改动范围的检查。CI 跑的是同一套，全部通过才能合并：

```bash
dart tool/task.dart analyze        # 分层检查 + flutter analyze
dart tool/task.dart test           # 只测当前分支影响到的包

# 改了 packages/foundation/*/rust 时
for d in packages/foundation/*/rust; do (cd $d && cargo clippy --all-targets -- -D warnings && cargo test); done

# 改了 packages/feature_base/moodiary_editor/editor 或 i18n/web 时
cd packages/feature_base/moodiary_editor/editor && corepack pnpm type-check && corepack pnpm test
```

Dart 代码用 `dart format` 格式化。UI 改动请在真机或模拟器上试过，并附截图。

## Pull Request

PR 会 squash 合并：**PR 标题就是提交标题**，**PR 描述就是提交正文**。两者都用英文。

### 标题：约定式提交

标题遵循 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。不符合时 `PR title` 检查会失败；检查同时按类型给 PR 打标签。

```
<type>[(scope)][!]: <description>
```

| 部分 | 规则 |
|---|---|
| `type` | 小写，取下表之一 |
| `scope` | 可选，小写，功能或包名：`diary`、`sync`、`editor`、`moodiary_data`、`i18n/web` 等 |
| `!` | 可选，标记破坏性变更 |
| `description` | 跟在 `: ` 后，祈使语气，结尾不加句号：写 `add`，不写 `added` / `adds` |

| 类型 | 用途 | CHANGELOG 分组 |
|---|---|---|
| `feat` | 用户可见的新功能 | Features |
| `fix` | 修 bug | Bug Fixes |
| `perf` | 性能优化 | Performance |
| `refactor` | 既不修 bug 也不加功能的代码改动 | Refactor |
| `docs` | 只改文档 | Documentation |
| `test` | 只改测试 | Testing |
| `style` | 格式调整，行为不变 | Styling |
| `build` | 构建系统、hook、工具链 | Miscellaneous |
| `ci` | CI 工作流 | Miscellaneous |
| `chore` | 其它不改动产品代码的杂项 | Miscellaneous |
| `revert` | 回滚之前的提交 | Revert |

```
feat(diary): add a year view to the calendar
fix(sync): degrade when the remote rejects a conditional write
refactor(rag)!: move the sqlite-vec binding into its own package
```

GitHub 的 Revert 按钮生成的标题是 `Revert "…"`，过不了检查；改成 `revert: <原提交标题>`，并在描述里写 `Refs: <sha>`。

### 描述：正文与 footer

按 PR 模板写改了什么、为什么、怎么测的，用不到的段落删掉。footer 是形如 `Token: value`（或 `Token #value`）的行，和上文之间隔一个空行，从 squash 提交里读取：

| footer | 作用 |
|---|---|
| `BREAKING CHANGE: <破坏了什么、怎么迁移>` | 标记为破坏性变更；可单独用，也可与标题里的 `!` 同时用 |
| `Changelog: skip` | 不写进 `CHANGELOG.md` |
| `Closes #123` | 合并后关闭对应 issue |

破坏性变更指：已有数据、备份、同步远端或局域网对端不经迁移就无法继续使用，或者删除了用户可见的功能。破坏性 PR 会被打上 `breaking` 标签，并且总会进 CHANGELOG，即使用了会被跳过的 scope。

会被 CHANGELOG 跳过的 scope：`chore(deps)`、`chore(readme)`、`chore(pr)`、`chore(pull)`、`chore(release)`。

### PR 的范围

- **一个 PR 只做一件事。** 顺手的重构或格式化会拖慢评审，请分开提。
- **数据格式。** 改数据库结构、同步布局或局域网协议必须带迁移方案，并在描述里写明。

发版由维护者负责，PR 里不要改版本号或 `CHANGELOG.md`。

## 社区

问题与讨论：[论坛](https://answer.moodiary.net) · Telegram [openmoodiary](https://t.me/openmoodiary) · QQ 群 760014526。
