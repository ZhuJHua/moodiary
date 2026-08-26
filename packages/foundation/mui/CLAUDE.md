### mui —— material 的补充，不是替代

Flutter 3.47 把 Material 拆成独立包 `material_ui`，SDK 内的
`package:flutter/material.dart` 将于 2026-11 弃用。全仓的规矩因此是：

**material 只经 `package:mui/mui.dart` 出。业务代码 import mui，不 import material。**
由 `tool/check_layers.dart` 零基线守住，名单外出现一处 legacy import 就红。名单目前 4 条
（wechat 的三个 picker 文件 + assistant 的 chat 页），都是第三方 API 只认 legacy 类型。

主题是**一棵树**：

- **`ColorScheme` 是配色真源，`TextTheme` 是排版真源**，mui 不再自建色板。
  `context.theme.colors` 返回的就是 material 的 `ColorScheme` 本体。
- `ThemeData` 装不下的东西收在单个 `MuiTokens extends ThemeExtension`：七张 token 表
  （圆角/间距/动效/描边/投影/状态）、`onMedia`，以及 **`MuiFontConfig`**——可变字体的 wght
  轴值只有宿主读过 ttf 才知道，`ThemeData` 没有槽位放它，漏了 `.emphasized` 会静默出错字重。
- `buildMuiTheme()` 是**全仓唯一构造 `ThemeData` 的地方**（闸门钉住），
  25 个组件子主题都在里面。
- `context.theme` 是 `Theme.of(context)` 的只读派生视图，按 `ThemeData` 实例 memoize。
  取用写法：`context.theme.typography.titleSmall.emphasized.primary`。
- **没有 `MuiAnimatedTheme`**：`MaterialApp` 已经把 `builder` 包在 `AnimatedTheme` 里，
  深浅切换的过渡是免费的。

组件：material_ui 够用的直接用（`Switch` / `Scaffold` / `AppBar`…），不够用的才在 mui 里补，
命名一律 `M` 开头（`MMenuButton`、`MAlert.show(...)`）。mui 是**零 `moodiary_*` 依赖**的
foundation 叶子包，所以它自带一份 slang 文案（十来个通用词），不吃 App 的文案包 —— 见下面
「i18n」一节。

> mui 的 slang 模式与全部坑见 `packages/foundation/moodiary_i18n/CLAUDE.md`；共存期的两个硬点
> （兼容桥 / localizationsDelegates / go_router 注记）见 `mobile/CLAUDE.md`。
