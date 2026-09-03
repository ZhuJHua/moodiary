# 8 个原生库的去留评估（2026-09-03）

问题：拆完之后 foundation 下有 8 个 `fast_*` 原生库，哪些其实不值得用 Rust、可以像字体解析那样
换成纯 Dart？判据只有一条——**Rust 在这里有没有 Dart 给不了的东西**（性能、能力、现成且靠谱的库），
没有就换掉。以下每条都附实测或核过的事实。

## 一、实测体积（Android arm64、release、stripped，本机 NDK 直出）

| 库 | 大小 | 桥 | 装载 |
|---|---:|---|---|
| fast_press | 33.10 MB | FRB | 首次导出 |
| fast_llm | 6.59 MB | FRB | 首次对话 |
| fast_text | 6.40 MB | FRB | 启动 |
| fast_image | 4.96 MB（模拟器实测） | FRB | 启动 |
| fast_http | 4.58 MB | FRB | 首次请求 |
| fast_zip | 1.00 MB | FRB | 首次打包（2026-09-03 晚已改纯 Dart，见第五节末） |
| fast_crypto | 0.41 MB | 裸 FFI | 无 |
| fast_graph | 0.35 MB | 裸 FFI | 无 |

合计约 57 MB。fast_http 与 fast_llm 各带一份 reqwest / rustls / tokio 底座与各自的 tokio 运行时。

## 二、逐个判定

### 换成 Dart（推荐，按顺序）

**1. fast_zip → `archive` 4.2.0（纯 Dart）。** 我们用到的只有：逐文件 / 逐字节写入、Stored 直存、
AES 密码、带取消的解压。`archive` 4.2.0 全有：`ZipFileEncoder(password:)` 流式写文件、AES-256
（WinZip AE-1）加密、AES 解密（changelog "Add Zip AES-256 decryption"）。取消 = 条目之间查标记。
代价：纯 Dart 的 Deflate / AES 是每秒几十 MB 量级——媒体本来就是 Stored 直存、不压缩，只有**带密码
的备份**会慢（100 MB 备份约多几秒）。跑在 `Isolate.run` 里不卡 UI。要验一件事：Rust zip crate 写的
是 AE-2、archive 写 AE-1，旧备份用 archive 解得开（两者解码器都通吃，但要拿真实备份跑一次）。
省 1.0 MB + 一个 FRB 包。工作量半天。

**2. fast_graph → 纯 Dart 移植。** 它是 830 行纯算法（ForceAtlas2 + Barnes-Hut + 碰撞），零外部
依赖、7 个单测；没有任何 Dart 给不了的能力。Dart AOT 跑这种浮点循环大约比 Rust 慢 2–4 倍：ego 图
几十个节点毫秒级根本感知不到；总图谱（已隐藏）2000 节点每帧几毫秒到十几毫秒，逐帧流式仍然顺。
移植成 `Isolate.spawn` 里的循环 + SendPort 推帧，取消 = 杀 isolate，比现在「原生线程 +
`NativeCallable.listener` + 终态事件才能 close」那套 unsafe 生命周期简单得多——**这是 8 个库里最
危险的一段代码**，换掉本身就是收益。移植时用同一份种子（黄金角螺旋，确定性）把 Dart 帧与 Rust 帧
逐帧对比再删 Rust。落点 moodiary_diary（唯一消费方）。省 0.35 MB + 一个裸 FFI 包。工作量一天。

**3. fast_http → `dart:io`。** 这是收益最大的一项。它做的每件事 dart:io 都原生就有：
- 客户端：`HttpClient` 自动解压 gzip（当初逼着 reqwest 开 gzip/brotli/deflate 的和风天气坑消失）、
  `contentLength` + `addStream` 的流式上传（不降级 chunked）、边收边落盘的下载 + 进度、超时；
  Android 上用系统信任库，没有 rustls-platform-verifier 那个 panic，自签 / 企业 CA 走
  `badCertificateCallback`。
- 服务端：`HttpServer` 回环监听 + token、单段 Range 回 206（约 40 行自己解析）、大请求体落盘
  阈值 + 进度、handler 异常折叠 500——**这套语义的 dart:io 实现已经存在于
  `lan_transfer_test.dart` 的 `IoTestHttpServer` / `IoTestHttpClient`**，等于实现写了一半。
- WebDAV：我们只用 8 个操作（PROPFIND / MKCOL / PUT / GET / DELETE / 独占创建 / stat），手写约
  200 行；Digest 认证（Rust 用了 digest_auth）RFC 7616 约 80 行。pub 的 `webdav_client` 1.2.2
  骑在 dio 上，不值得为它引 dio。
- S3：SigV4 签名约 150 行（`crypto` 包 HMAC-SHA256）+ 少量 XML；pub 的 `minio` 3.5.8（128 likes、
  纯 Dart）也可用，但我们的操作面很窄，手写更省依赖。
当初（2026-07-15）「客户端统一 Rust、去 shelf」是组织上的统一，不是能力缺口；memory 里没有一条
dart:io 做不到的记录。代价：重新验证 LAN 收发与 WebDAV / S3 的真实服务器（Nextcloud / 坚果云 /
MinIO）。省 4.58 MB + 一个 tokio 运行时 + 一个 FRB 包。工作量 2–3 天。

**4. fast_llm → 手写 SSE 流。** rig 提供的是三种协议（completions / responses / messages）的流式
多轮 + 工具循环。Dart 侧就是 dart:io 请求 + 按行解析 `data:` + 三份请求体 / 事件映射 + 工具循环，
约 1000 行；pub 上没有值得引的（`openai_dart` / `anthropic_sdk_dart` 拖一大坨生成模型，不如手写）。
风险在协议细节：Anthropic 思考块的 `display`、旧 budget_tokens 400、prompt caching 头、responses
API 的事件形状、工具调用增量拼接——这些是踩过的坑，全部要在真实供应商上重跑一遍，是四项里唯一
必须联网验证的。省 6.59 MB + 第二个 tokio 运行时 + 一个 FRB 包。工作量 3–4 天。**放最后。**

### 留在 Rust（有 Dart 给不了的东西）

**fast_image。** 巨图按区域解码（turbojpeg 的 iMCU 裁剪 + restart marker 随机访问、WebP / PNG
区域解）是 Flutter 没有的能力——`dart:ui` 只有整图按目标尺寸缩放解码，没有区域解，纯 Dart 的
`image` 包解 4000 万像素要几秒且整张进内存。整条分片看图管线就是为此建的。留。

**fast_press。** PDF 用 typst 是实测选的：Dart `pdf` 包对中文长文是二次方（4 万字 55 秒、8 万字
跑不完，32 万字外推 8 小时），typst 0.29 秒。留。DOCX 那一半（docx-rs，1041 行）可以 Dart 化
（OOXML = XML + zip，代码高亮已有 re_highlight），但**不减少库的数量**，只能让 fast_press 瘦一点，
优先级低。

**fast_text。** jieba 词典就是那 6.4 MB 的大头，Dart 侧没有可用替代：`jieba_flutter` 是 GPL-3.0
（许可证不兼容），`dart_jieba` 158 次下载、单人维护；自己把 35 万词的词典装进 Dart 堆要几百毫秒到
秒级的启动开销与几十 MB 内存，而 Rust 侧 100 ms 建完、批量分词实测比逐条快 6 倍，搜索索引与迁移
都在这条路上。HF tokenizer（Qwen3 的 byte-level BPE）Dart 能写，但单独换它没有收益。留。

**fast_crypto。** 本机实测（M 系列 Mac，Dart AOT vs Rust release）：

| 操作 | 纯 Dart | Rust | 倍数 |
|---|---:|---:|---:|
| 应用锁 Argon2id（m=19456, t=2, p=1）| 79 ms | 13 ms | 6× |
| 同步 KDF Argon2id（m=65536, t=3, p=4）| 402 ms | 79 ms | 5× |
| AES-256-GCM 加密 20 MiB | 1125 ms（18 MB/s） | 11 ms | **100×** |

Argon2 慢 5–6 倍勉强能忍（手机上应用锁解锁大概 0.3–0.5 秒），但 AES 差两个数量级：同步的每个
媒体对象都要过一遍加解密，一个 50 MB 视频纯 Dart 要 3 秒。`cryptography_flutter` 走平台原生 AES
能追回来，但那也是一个原生插件，只是别人的 .so。它只有 0.41 MB、没有 init、代码 500 行。留。

## 三、结论

| | 现在 | 做完 1–4 |
|---|---|---|
| 原生库数 | 8 | **4**（image / press / text / crypto） |
| FRB 包数 | 6 | 3 |
| tokio 运行时 | 2（http / llm） | 0 |
| .so 合计 | ≈ 57 MB | ≈ 45 MB |

顺序：fast_zip（半天，最低风险）→ fast_graph（一天，帧对帧校验）→ fast_http（2–3 天，LAN 与
云端真实服务器回归）→ fast_llm（3–4 天，三家供应商联网回归）。每项一个提交，照拆分时的做法。

## 四、重复依赖实测（2026-09-03，cargo-bloat 宿主 `.text` 归因）

判据从「功能独立」改成「二进制里真的重复了什么」。两两之间共享 crate 的实际字节（MiB）：

| | image | press | http | llm | text | zip | crypto | graph |
|---|---|---|---|---|---|---|---|---|
| image | – | 1.30 | 0.62 | 0.57 | 0.69 | 0.42 | 0.23 | 0.23 |
| press | | – | 1.02 | 1.62 | 1.49 | 0.57 | 0.23 | 0.23 |
| http | | | – | **2.07** | 0.81 | 0.42 | 0.24 | 0.23 |
| llm | | | | – | 0.84 | 0.41 | 0.24 | 0.23 |
| text | | | | | – | 0.42 | 0.23 | 0.23 |
| zip | | | | | | – | 0.22 | 0.23 |
| crypto | | | | | | | – | 0.21 |

每个库必带的地板（std 用到的那部分 0.2–0.4 MiB、tokio + FRB + 线程池 ≈ 0.35、backtrace 那套
gimli / addr2line / object ≈ 0.27——FRB 直接依赖 backtrace crate，去不掉）占了矩阵里绝大部分数字。
扣掉地板后**真正的重复**只有四处：

| 重复 | 实际字节 | 内容 |
|---|---:|---|
| http ∩ llm | ≈ 2.0 MiB | rustls 314K、ring 157K、reqwest 112K、hyper 86K、hyper_util、webpki、url、brotli……整套网络底座 |
| press ∩ image | ≈ 0.7 MiB | typst-library 自带的 image / image_webp / zune_jpeg / tiff / png 解码 |
| press ∩ text | ≈ 0.6 MiB | syntect 与 tokenizers 各带一份 regex_automata / regex_syntax / aho_corasick / fancy_regex |
| press ∩ llm | ≈ 0.3 MiB | serde / serde_core |

已证伪：`cargo tree` 里 regex 出现在 6 个库，但二进制里没有——去掉 FRB 的 `user-utils`
实测只省 96 字节（链接期早剥掉了）；`rust-async` 去不掉（生成代码依赖 `Lockable`）。
**依赖树重叠不等于二进制重复，只认 bloat。**

结论：按「不重复依赖」分组，唯一该合并的是 **http + llm（含 sync）→ moodiary_rust**，包内分层
http → sync / llm，延迟装载保留。press 与 image / text 之间那 1.3 MiB 是 typst 自带的解码器与
regex，press 33 MB 且按需装载，不值得为它合并任何东西。text / crypto / graph 与谁都不重复，
并进去只省各自 0.2–0.4 MiB 的地板：text 启动装载应独立，crypto 留裸 FFI，graph 直接 Dart 化。

## 五、执行结果（2026-09-03）

- `moodiary_rust` = http → sync / llm（共享网络底座）+ graph（用户拍板并入，不 Dart 化）；四个门面
  各有主，延迟装载。
- `fast_tokenizer`（原 fast_text）、`fast_image`、`fast_press`、`fast_zip`、`fast_crypto` 独立。
- **fast_* 统一走 FRB**：fast_crypto 从裸 dart:ffi 改回 FRB（用户拍板：FRB 成熟，0.3 MB 地板可以接受）。
  门面 `Aes` / `Argon2` 每次调用自己 `ensureInitialized`，调用方不用 init。
- 第二节里「换成 Dart」的四项当时都没有采纳（zip / graph / http / llm 留 Rust）；网络层长期留 Rust。
- 结果：8 → 6 个原生库，全部 FRB；两个 tokio 运行时归一。
- **补记（同日晚）：fast_zip 改用纯 Dart `archive` 4.2.0，原生库降到 5 个。** 落点 `moodiary_utils`
  的 `ZipWriter`（专属 isolate 的命令队列，主 isolate 逐条目发命令、取消照旧在两次 add 之间查）与
  `extractZip`（整段 `Isolate.run`，自己做 zip-slip 校验、不吞写盘错误）。第二节没验的那件事验了：
  宿主 AOT 实测 Stored 写 226 MB/s / 读 1.2 GB/s，**zip 内 AES 只有 17 / 19 MB/s，且 `archive` 对加密
  条目整块进堆**——所以 LAN 归档不再用 zip 密码，改为明文 zip + 条目内容走 `SyncCipher(会话密钥)`
  （云同步同一套 magic + AES-GCM 对象格式，媒体整文件经 fast_crypto 原生加密），接收端
  `requireEncrypted` 拒收明文条目，接替 Rust 侧「传了密码就要求条目确实加密」那道闸。

## 六、libfastpress 33 MB 里是什么（2026-09-03，Android arm64 stripped 实测）

段：`.text` 18.42 MB、`.rodata` 8.73、`.eh_frame` 1.83、`.rela.dyn` 1.76、`.data.rel.ro` 1.33、
`.gcc_except_table` 0.63。typst 自带字体没进来（`typst-assets` 的 `fonts` 没开）。

**`.rodata` 8.73 MB**（符号表只认得 0.9 MB，其余是 `include_bytes!` 的匿名块，用资源文件的字节片段
回搜 .so 归因）：

| 数据 | MB | 日记导出用不用 |
|---|---:|---|
| hayagriva 参考文献 CSL 样式 + locale（cbor） | 2.95 | 不用 |
| two-face 语法包（typst `raw` 的高亮，我们 PDF / DOCX 代码块都用） | 2.65 | **用** |
| hypher 48 种语言的连字模式 | 1.11 | 中文不用，西文 justify 时才用 |
| unicode / icu 表、typst 内置函数文档串等散项 | ≈ 2.0 | 混杂 |

**`.text` 18.4 MB**（宿主 bloat 归因，按子树）：

| 子树 | MiB | 日记导出用不用 |
|---|---:|---|
| typst 核心（library / layout / eval / syntax / realize） | 3.80 | 用 |
| std / core / alloc（泛型实例化） | 3.54 | 地板 |
| 参考文献 hayagriva / citationberg | 1.52 | 不用 |
| 光栅图解码 image / webp / jpeg / png | 1.29 | 用（照片） |
| PDF 当图片嵌入 hayro | 1.19 | 不用 |
| 字体 / shaping rustybuzz / skrifa | 1.02 | 用 |
| 插件 wasmi / wasmparser | 0.95 | 不用 |
| SVG usvg / resvg / typst_svg | 0.79 | 不用 |
| 代码高亮 syntect / regex | 0.74 | 用 |
| PDF 写出 krilla | 0.71 | 用 |
| docx-rs / zip | 0.52 | 用 |

「永远不会执行」的子树合计：`.text` 4.5 + `.rodata` 3.0 + 它们摊到的重定位 / unwind ≈ **8 MB**。
它们关不掉的根因见 memory `typst-size-tradeoff`：typst 全家零 feature、官方拒绝、过程宏不支持 cfg、
`hayro → typst-svg → typst-html → typst-realize` 这条链把排版必需件和 SVG / HTML 锁在一起。

**可选的刀**（都是实测或按上表推算）：

| 刀 | 省 | 代价 / 风险 |
|---|---:|---|
| `lto = "fat"`（只对 fast_press） | **−1.6 MB**（34.70 → 33.07 MB，实测） | 构建 198 s；零风险 |
| `[patch.crates-io]` 桩掉 hayagriva（+citationberg） | ≈ −4.5 MB | 一个桩 crate 复刻 typst-library 用到的类型签名（约 200–300 行）；我们从不发 `#bibliography` / `#cite`，桩路径不会被执行；typst 升级时桩编不过会立刻暴露，不是静默回归 |
| 再桩 hayro / wasmi / usvg+resvg | ≈ −1.3 / −1.0 / −0.9 MB | 同上，各一个桩；四个桩合计 ≈ −8 MB → 约 25 MB |
| `panic = "abort"` | ≈ −3 MB | 失去 FRB 的 panic → Dart 异常兜底，typst 在脏输入上会杀进程；此前已否决 |
| `opt-level` 降档 | −4 MB 量级 | 排版 +19%；此前已否决 |
| 去掉导出的代码高亮 | −3.4 MB | 产品功能退化，不建议 |
| Android Play Feature Delivery：fast_press 做按需下载模块 | 首包 −33 MB（下载约 −15 MB） | 只对 Play 分发有效，iOS 无对应机制；要动 Gradle dynamic feature + split 安装后的 dlopen 路径 |

下载体积口径：APK 里 .so 不压缩，Play 下发压缩后约为 raw 的 45%（33 MB ≈ 15 MB 下载）。

### 社区有没有现成的精简 fork（2026-09-03 查）

没有。查过的全部落空：

- 上游 [#3857](https://github.com/typst/typst/issues/3857)（2024-04，荷兰选举委员会提的「加 feature flag 缩体积」）被维护者以
  「flag 多了没法测」拒绝并关闭；他们给的示例提交
  [07fff038](https://github.com/typst/typst/commit/07fff038be531a267942c1fbd8a89c55ab15b601) 只把 `cbor` 加载
  gate 掉（2 个文件 8 行），从没进主线。同一串里 zinifier 实测砍掉引文 / SVG / 公式 / WASM / 数据加载 / 大纲
  能 36 → 25 MiB（−30%），但他的 [fork](https://github.com/zinifier/typst) 只有 `main` 和 `public-cli-crate`
  两个分支，那份实验没有发布。
- 提需求的人自己的正式项目 [kiesraad/abacus](https://github.com/kiesraad/abacus)（`backend/pdf_gen/impl/Cargo.toml`）
  最终用的是原版 `typst = "0.15.0"` + `typst-pdf`，没有 fork、没有 patch——连最在意供应链的人都放弃了裁剪。
- typst 主线 `crates/typst-library/Cargo.toml`（main）至今零 `[features]`、零 `optional = true`；
  0.15 的 `--features html` 是运行时开关，与二进制无关。
- [Myriad-Dreamin/typst.ts](https://github.com/Myriad-Dreamin/typst.ts)（把 typst 跑进浏览器，最在意体积）确实用
  自家 fork（tag `typst.ts/v0.8.1`），但那是为 wasm 兼容改的，其 typst-library 同样零 feature。
- crates.io 上带 typst 的 43 个 crate 没有任何 lite / slim / pdf-only 变体；GitHub 代码搜索里
  `[patch.crates-io]` 桩 hayagriva 的公开仓库为 0。

所以精简版只能自己养。两条路，耦合面都小（typst-library 里引用 hayagriva 67 行 / wasmi 21 行 /
usvg 60 行 / hayro 4 行；typst-html 经 `typst` 与 `typst-realize` 两处 `use` 进来）：

| 路 | 做法 | 维护成本 |
|---|---|---|
| A. `[patch.crates-io]` 桩 | 不动 typst；给 hayagriva+citationberg / wasmi / usvg+resvg / hayro 各写一个 API 同形的空壳 crate | typst 升级时桩编不过 → 补签名；typst 本体仍是 registry 原版 |
| B. fork 三个 crate 加 feature | 照 07fff038 的样子给 typst-library / typst-realize / typst 加 `bibliography` / `plugin` / `svg` / `html` feature，约 150–200 行 | 整个 typst workspace 改成 git 依赖，每次升级 rebase |

A 更省心（typst 永远是原版，只多四个几十到几百行的小 crate），先做 hayagriva 那一个就拿回 ≈ 4.5 MB。

### 落地：fork typst（2026-09-03）

选了 B。fork 在 `ZhuJHua/typst` 的 `moodiary/slim` 分支（基于 v0.15.1 tag，一个提交），加了六个
默认开启的 opt-out feature：typst-library `bibliography` / `plugin` / `svg` / `pdf-image`，typst-pdf
`svg` / `pdf-image`，typst-realize + typst `html`，typst-layout `hyphenation`。元素类型经桩模块保持
同形，其余 crate 零改动；两种配置 clippy 零警告、单测全过、整个 workspace 默认构建不变。
fast_press 用 `[patch.crates-io]` 钉 rev 并 `default-features = false`，依赖树里 hayagriva /
wasmi / usvg / hayro / typst-html / typst-svg / hypher 归零。
**libfastpress：33.10 → 18.58 MB（−44%）**（Android arm64 stripped；`.text` 18.42 → 11.63，`.rodata` 8.73 → 3.14）。
比第六节按子树估的 8 MB 多省了一倍——那些子树还各自拖着一份 std 泛型实例化、unicode / icu 表与 unwind 数据。
两个坑：fork 的 `main` 比 v0.15.1 多 120 个提交（krilla 已换 git 版本），必须从 tag 开分支；
workspace 依赖上不关 `default-features`，cargo 的 feature 合并会把默认全开回来，`cargo tree`
看着 patch 生效了其实一个都没关。
