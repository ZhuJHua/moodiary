# `lib/component/`：业务无关组件库

`component/` 是分层模型中的**共享 UI 层**（位于 `data` 之上、`feature` 之下）。详见 `CLAUDE.md` 的「Layered Dependencies」与 `tool/check_layers.dart`。

## 分层契约

| 层 | 路径 | 含义 | 准入要求 |
|---|---|---|---|
| 基础层 | `lib/component/basic/` | 不依赖任何业务 model / repository / controller | 仅依赖 Flutter SDK、`l10n`、`core/` |
| 通用业务 | `lib/component/common/` | 允许引用业务 model（如 `Diary`），但不许直连 controller / repository | 仅依赖 `core/`、`data/`、`l10n`、`basic/` |
| feature 内部 | `lib/feature/<feature>/presentation/widget/` | 强耦合 feature 的 widget（含 Riverpod 订阅） | 任意（但不得跨 feature 引用） |

## 硬性规则

`component/` 内的任何文件都**不许** `import 'package:moodiary/feature/...'`（component 是 feature 的下层）。被多个 feature 复用的 widget（如 `common/video_player.dart`、`common/audio_player.dart`、`common/async_value.dart`）一律放在 `component/common/`，由各 feature 向下引用。

违反会被 `dart tool/task.dart check-layers`（CI 的 "Check Layer Dependencies" 步骤）拦截。
