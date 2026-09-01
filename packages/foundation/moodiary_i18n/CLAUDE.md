### i18n —— slang，不是 gen-l10n

文案由 **slang 4.19** 生成，`flutter_localizations` 退回只服务 material 组件自己的字串
（且它不会从依赖图消失：material_ui 与 slang_flutter 都依赖它）。

**三个词各指一样东西，全仓按这个分**：

| 词 | 指什么 | 用在哪 |
|---|---|---|
| **i18n** | 让程序**有能力**适配任意语种的那套机制：文案外部化、语种解析、复数规则、代码生成 | 包名 `moodiary_i18n`、目录 `i18n/`、`slang.yaml`、`dart tool/task.dart i18n`、`i18n_test.dart` |
| **l10n** | 某个语种下的**具体文案**，也就是取串拿到的那个对象 | `context.l10n` / 顶层 `l10n` / `context.muiL10n` / 局部 `final l10n = …` |
| **Localizations** | Flutter `Localizations` widget 那条链（delegate + `.of(context)`） | 只给真走那条链的：`GlobalMuiLocalizations` / `MuiLocalizations` / `MuiLocalizationsData` |

按这个分，**App 那份不该叫 `MoodiaryLocalizations`**：它走 slang 自己的 `TranslationProvider`，
压根不经过 Flutter 的 `Localizations`，叫那个名字是指错实现。走那条链的全仓只有 mui。
反过来，**枚举转显示名一类的方法也不该叫 `l10nText`**（已改名 `Language.label`）——
返回的是一句 label，「它是本地化的」是所有 UI 文案的共性，不构成名字的一部分。

全仓有**两份**互不相干的 slang 产物，各自 `slang.yaml`，**而且用的是 slang 的两种模式**：

| | 源文件 | 产物 | 模式 | 符号 |
|---|---|---|---|---|
| App | `moodiary_i18n/lib/i18n/<ns>_{zh,en}.i18n.json` | `strings.g.dart` | 默认（全局 `LocaleSettings` + `TranslationProvider`） | `Translations` / `AppLocale` / `l10n` |
| mui | `mui/lib/src/i18n/{zh,en}.i18n.json` | `strings.g.dart` | `locale_handling: false` + 手写 delegate | `MuiLocalizationsData` / `MuiLocale` / `context.muiL10n` |

**两种模式对应两种角色，别互相看齐**：

- **App 是根**：类名冲突由它说了算，而且 service / 导出 / 回调里大量用顶层 `l10n`（那里
  拿不到 context），所以走默认模式 —— `runApp` 里挂 `TranslationProvider`，
  `applyStoredLanguage()` 调一次 `LocaleSettings.setLocale`。语种真源是 slang 的
  `GlobalLocaleState` 单例，KV 里只存偏好枚举，`MaterialApp.locale` 从
  `TranslationProvider.of(context).flutterLocale` 取。
- **mui 是被别人 import 的包**：它关掉了 `locale_handling`，产物里**没有 `LocaleSettings`、
  没有 `TranslationProvider`、没有顶层 `muiL10n` 变量**，只剩 `MuiLocale` 枚举与
  `MuiLocalizationsData` 类，外面套一层手写的 `GlobalMuiLocalizations`
  （`LocalizationsDelegate`，同 `GlobalMaterialLocalizations`、shadcn_ui 的
  `GlobalShadLocalizations`）。宿主把它加进 `MaterialApp.localizationsDelegates` 即可，
  **不需要知道 mui 内部用了 slang**；当前语种就是 `MaterialApp.locale` 解析出来的那个。
  组件里照旧写 `context.muiL10n.ok`（extension 是手写的，不是生成的）。

  **文案一律走 mui 自己这张表，别从 `MaterialLocalizations` 取。** 2026-08-20 试过一次
  当天撤回（`ok` / `cancel` / `back` / `save` 这四个 material 确实也有，改读它能白得 116
  个语种）——不做的理由有三条：①等于把用户可见文案的所有权交给一个我们不控制版本的上游，
  它的措辞随 SDK 变（实测我们的「确认」在 material 里是「确定」），界面会跟着静默改而没有
  闸门会报；②「这个词从哪来」从一个答案变成两个；③`MaterialLocalizations.of` 是
  `assert` + `!`，缺了直接崩，比 `MuiLocalizations.of` 的 debug 断言 + release 回落更脆
  （离屏测量那条路径不带 `Localizations`）。shadcn_ui 也是这么选的：它那 11 个键里根本
  没有 ok/cancel，而 material 明明有的 `cut` / `copy` / `paste` / `selectAll` 它照样自己
  带、铺到 82 个语种。

  换来三件事：①两份产物不再撞名，生成物 `show MuiLocalizationsData` 出去就够，不必再包一层
  scope；②宿主漏挂 delegate 只是回落 base 语种（debug 下 `MuiLocalizations.of` 断言），
  不像 provider 缺失那样在每个组件里直接抛；③语种真源只剩 `Localizations` 一处，与「谁先调
  `setLocale`」的启动顺序脱钩 —— 旧实现里 `runApp` 之前切语种那一轮通知是落空的。
  闸门在 `mui/test/i18n_test.dart`。

App 那份按 **namespace 一个 feature 一份文件**：`common`（无领域含义的基础词）+
`app` / `diary` / `assistant` / `export` / `sync` / `media` / `editor` / `ui` / `lock` /
`share`。取串写成 `l10n.diary.searchResult`；**删 feature 就删它那两个文件**。

**feature 包不各自装 slang**（只有 mui 例外，因为它是零 `moodiary_*` 依赖的对外叶子包）：
namespace 已经给到分域的全部好处，不必为每个 feature 再付一份产物、一次挂载。

- **取串按有没有 context 分**：widget 里用 `context.l10n.xxx`（依赖 `TranslationProvider`，
  切语言自动重建）；service / 导出 / 回调里用顶层的 `l10n.xxx`（**不会重建**）。
- **参数是具名的**：`l10n.diarySearchResult(count: n)`。gen-l10n 时代的位置参数已全部改完。
- 改了 `*.i18n.json` **必须跑 `dart tool/task.dart i18n`**（产物是提交的，且没有闸门兜底）。
- 查死键要开 `--full`（不开只比对语种间差集），并把源码目录指回仓库 —— 默认只扫当前包的
  `lib/`，那里一个调用点都没有。在 `moodiary_i18n` 下跑，约 9 秒：

  ```bash
  dart run slang analyze --full --source-dirs=../../../packages,../../../mobile
  ```

  它是**去空白后的子串匹配**，所以 mui 的 `muiL10n.back` 里含 `l10n.back`，会让 App 侧同名
  的死键假装被用了。取名时别让别的变量以 `translate_var` 收尾。

四个不报错的坑：

1. **`TranslationProvider` / `LocaleSettings` / `AppLocaleUtils` 三个类名在生成器里是硬编码的**，
   只有 `class_name` / `enum_name` / `translate_var` 可配。mui 关掉 `locale_handling` 之后
   只剩 `AppLocaleUtils` 还会生成，所以它的产物**仍然不整个进 barrel**，只
   `show MuiLocalizationsData`；生成物顶部还有一句 `export 'package:slang_flutter/…'`，
   裸导出会把整个 slang_flutter 一起带出去。
2. **复数是英文的需求，中文被顺带拖进来**：slang 要求同一个键在所有语种里节点形状一致，
   所以 `1 entry / 2 entries` 这类键的中文侧也是复数节点（只有 `other`）。而 slang 的内置
   复数规则表里没有 zh（只有 ar cs de en es fr he it ja pl ru sv uk vi），渲染中文时**每次
   都走一遍 `print`** 再用兜底（`log.error` 就是裸 print，release 也打）。`setupPluralResolvers()`
   就是来说「zh 一律取 other」的，在 `runApp` 之前登记即可（与 `setLocale` 先后无关，
   但它不会通知已挂载的 provider）。mui 那份没有 `LocaleSettings`，将来真加了复数键得从
   delegate 的 `buildSync(cardinalResolver: …)` 传进去。
3. **非 base 语种的翻译类默认是 deferred import**（`lazy: true`），所以 App 那份一律用
   异步的 `setLocale`，别用 `setLocaleSync`（它绕开 `loadLibrary()`）。
   **mui 那份钉 `lazy: false`**：delegate 的 `load()` 用 `buildSync` 直接返回
   `SynchronousFuture`（`Localizations` 因此不多等一帧，widget 测试也不用多 pump 一次），
   而 `buildSync` 恰恰绕开 `loadLibrary()` —— 把 lazy 打开就得同时把 delegate 改成异步的
   `build()`，否则 web 上直接抛。闸门在 `mui/test/i18n_test.dart`（比对生成物里没有
   `deferred as`）。
4. `timestamp` 与 `flat_map` 默认都是 `true`：前者让提交的产物每次生成都有噪声 diff，
   后者多生成一份全量 `Map<String, String>`。两个都在 `slang.yaml` 里关掉了。
5. **`analyze` 是按 `l10n.` 前缀做子串匹配的，存成局部别名它就瞎了**：写
   `final t = l10n.assistant;` 再 `t.toolUntitled`，那个键会被报成未使用，照着删就是运行时
   少一句文案。取串一律把 `l10n.xxx.yyy` 写全。

**读者是谁，决定这串走不走 slang**（助手这边尤其容易混）：

| 读者 | 例子 | 怎么写 |
|---|---|---|
| 模型 | 系统提示词、工具描述、入参 schema、工具**返回文本** | 英文写死在源码里，不进 i18n |
| 用户 | 提示条上的类型词与摘要、错误提示 | 走 slang |

工具返回文本进的是对话上下文，翻译它等于按用户语言改模型的输入；而同一次调用在界面上
显示成什么，是 `AssistantTool.summarize` 另算的一份、走 l10n。两者**不共用字符串**。

**同步事件不带文案**：`SyncEvent` 只落机器字段（kind / level / reason / payload），展示文案由
日志页按 kind / reason 取 l10n。引擎侧不要往事件里写死中文 message——同 kind 下语义不够用时，
加 `SyncEventReason` 枚举值或 payload 字段，别塞句子。抛给用户的 `SyncException` 同理，走
`l10n.sync.err*`。日志页的 `_kindLabel` / `_kindIcon` 是 exhaustive switch 不是 Map：加了 kind
忘配文案会编译报错，而不是静默漏出原始枚举名。

**哪些中文字面量该留着**（扫描器会一直报它们，别每次都重新判断一遍）：

- **助手里读者是模型的那些串**（`moodiary_assistant/lib/src/data/`）：系统提示词、工具描述、
  工具入参 schema、工具返回的文本，**一律英文写死，不进 slang**（见上面「读者是谁」一节）。
  扫描器不会报它们，但别顺手「补翻译」。
- **不是文案的字符串**：`'宋体'` 是字体族名、`'『压测』'` 是压测日记的标题标记（翻了就认不出
  历史数据）、ICP 备案号是法律标识、`logger.e` / `assert` 的文字进的是日志文件。

> slang 自带的 `dart run slang migrate arb` **不能用**：它按 camelCase 把键强行拆成嵌套路径
> （`accentCustomTitle` → `accent.custom.title`），既改掉全部调用点，又会在
> `accentCustom` / `accentCustomTitle` 这种前缀重叠上直接抛异常。当年是脚本平铺转的。

