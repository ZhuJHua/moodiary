# moodiary_rust 拆分计划（2026-09-03）

> ⚠️ **本计划已被同日的回收决定部分推翻，别照着它读现状。** 当天确实按 fast_press → fast_http →
> fast_llm → fast_text → fast_crypto → fast_graph → fast_zip → 字体 Dart 化的顺序逐步执行过，
> 但随即又把 http / sync / llm / graph 合并回了 `moodiary_rust`——**该包今天仍然存在**，
> `fast_http` / `fast_llm` / `fast_graph` / `fast_text` 这四个包都不在仓库里（fast_text 更名 fast_tokenizer）。
> **终态以 `docs/native-libs-review.md` 第五节为准**：6 个原生库 = moodiary_rust + fast_image /
> fast_press / fast_tokenizer / fast_crypto / fast_zip。以下是决策时的原文。
> 后续变动见 docs/native-libs-review.md 第五节（同日回收成 6 个库；fast_zip 当晚改纯 Dart `archive`，
> 次日因局域网线上兼容又改回 Rust，仍是 6 个）。

目标（2026-09-03 已拍板，见第四节「决策」）：`moodiary_rust` 只留 moodiary 专属的业务 Rust；与 moodiary 无关的能力各自成包（`fast_*`，
foundation 层，自带 FRB 与原生库，形状同 fast_image / fast_press），并且**按需延迟初始化**，
启动路径只装载启动真正要用的库。

## 一、现状盘点（fast_image / fast_press 拆走之后）

| crate | 行 | 内容 | 重依赖 | Dart 消费方 |
|---|---:|---|---|---|
| http | 2260 | reqwest 客户端（含上传/下载流）+ hyper 应用内服务端 | reqwest / rustls / tokio / hyper（110 个 crate） | moodiary_http（core） |
| sync | 1612 | S3（rusty-s3 签名）/ WebDAV（reqwest_dav）对象级读写 | **复用 http 的 `client::shared()`** | moodiary_sync |
| assistant | 984 | rig 对话流 + 工具回调 | rig-core / rig-agent，**复用同一个 reqwest Client** | moodiary_assistant |
| text | 804 | jieba + stemmer + CJK 分段 | jieba-rs（词典进 rodata） | moodiary_data / diary / assistant，测试替身 |
| hf_tokenizer | 168 | HF tokenizer.json 封装 | tokenizers（与 jieba 共享 regex 三件套） | moodiary_ml |
| crypto | 540 | AES-256-GCM + Argon2id | ring / argon2 | moodiary_sync（Aes）、moodiary_storage（Argon2） |
| archive | 566 | zip 读写（AES、stored） | zip | moodiary_export / moodiary_sync |
| font | 110 | TTF 全名 / wght 轴 | ttf-parser fork | moodiary_theme |
| graph | 1660 | ForceAtlas2 + Barnes-Hut 布局流 | 无 | moodiary_diary |
| cancel（api） | 37 | 取消令牌 | — | http / zip 的调用方 |

（QuickJS 沙箱 2026-09-03 已整个摘除：Rust 侧与助手的 runJavascript 工具都删了，留 TODO，下一版不走 Rust 包装。）

**没有一个 crate 认识「日记」。** assistant 自己的文档写着「Rust 侧完全通用、不认识日记」；sync 只做
对象读写；text 是通用分词。按「专属才留」的口径，`moodiary_rust` 的终态是**空掉并删除**。

## 二、体积账

宿主 arm64 release、不剥符号，cargo-bloat 按 crate 归因（thin LTO 下归因是猜的，量级可信）。
`.text` 8.49 MiB，`__const` 3.9 MiB（jieba 词典、webpki 根证书、unicode 表），文件 17.1 MiB。

| 组 | .text | 占比 | 备注 |
|---|---:|---:|---|
| 网络底座（reqwest/rustls/ring/tokio/hyper/h2/url…） | 1.90 MiB | 22% | 再加 std/Unknown 里被内联的那部分，真实≈3 MiB+ |
| rig（assistant） | 1.70 MiB | 20% | serde_json 也算在这里 |
| tokenizers（hf） | 1.13 MiB | 13% | 含 regex 三件套 0.6 MiB，与 jieba 共享 |
| std + FRB + Unknown | 2.99 MiB | 35% | 每个库都要各带一份「用到的那部分」 |
| sync（s3+webdav） | 0.20 MiB | 2% | |
| text（jieba） | 0.19 MiB | 2% | 词典在 __const，不在这里 |
| archive（zip） | 0.18 MiB | 2% | |
| crypto / font / graph | 0.03 / 0.02 / 0.01 MiB | <1% | 三个小到地板都比它大 |

Android arm64 真实基线（release、stripped，本机 NDK 28.2 直出，含 QuickJS 时）：

| 库 | 字节 | |
|---|---:|---|
| libmoodiary_rust.so（今天） | 16,346,576 | 15.6 MiB |
| libfastpress.so | 34,704,288 | 33.1 MiB |
| 拆 fast_press 之前的 libmoodiary_rust.so（含 typst，不含图片） | ≈ 45.8 MB | 模拟器实测 |

**一次拆分的真实代价**：45.8 → 15.6 + 33.1 = 48.7 MB，**+2.9 MB**。远高于 294 KB 的空壳地板，
多出来的是两边各带一份的 std / FRB（含 tokio）/ regex / serde / flate2。带 FRB 运行时的真实地板见第八节。

## 三、硬约束（都是实测过的，别重推）

1. **跨 .so 不能共享 Rust 代码**：Rust ABI dylib 在 thin LTO 下直接被 rustc 拒绝、关 LTO 是 +170%；
   C-ABI 共享要手写 extern "C"。所以每个库静态各带一份 std + FRB 运行时（FRB 默认 `rust-async`
   带 tokio），空 cdylib 地板 294 KB，带 FRB 的地板更高（待实测）。
2. **http / sync / assistant 是一体的**：三者共享 110 个 crate（整套 reqwest/rustls/tokio/hyper），且
   sync 与 assistant 复用 `moodiary_http::client::shared()` 同一个 reqwest Client（连接池 + TLS 根）。
   分家 = 每份各一套底座 + 各自的 tokio 运行时与线程池。
3. **FRB 不透明句柄跨不了库**：`CancelToken` 每库一枚（fast_press 已经这样）。
4. jieba 与 tokenizers 共享 regex 三件套（≈0.6 MiB），分开就重复。

## 四、方案：6 个 `fast_*` 包 + 字体解析 Dart 化

| 包 | 原生库 | 桥 | 内容 | 来源 crate | 消费方 | `_nativePkgOwners` | 初始化时机 |
|---|---|---|---|---|---|---|---|
| **fast_http** | libfasthttp | FRB | `HttpClient` / `HttpServer` / `DavClient` / `S3Client` / `CancelToken`（全是 HTTP 协议） | http + sync | moodiary_http、moodiary_sync | 登记这两个 | 首次请求 / 编辑器回环服务启动 |
| **fast_llm** | libfastllm | FRB | rig 对话流（自建 reqwest，注入 webpki-roots） | assistant | moodiary_assistant | 登记 | 首次打开助手 |
| **fast_text** | libfasttext | FRB（可迁裸 FFI） | jieba + stemmer + HF tokenizer + 测试替身 | text + hf_tokenizer | data / diary / assistant / ml | 不登记（多 owner） | 启动（搜索索引与迁移都要） |
| **fast_crypto** | libfastcrypto | **裸 FFI** | AES-GCM + Argon2id | crypto | moodiary_sync、moodiary_storage | 不登记 | 启动（应用锁 PIN 在启动路径） |
| **fast_zip** | libfastzip | FRB（可迁裸 FFI） | zip 读写 + `CancelToken` | archive | moodiary_export、moodiary_sync | 不登记 | 首次导出 / 备份 |
| **fast_graph** | libfastgraph | **裸 FFI** | ForceAtlas2 布局流 | graph | moodiary_diary | 登记 | 首次打开图谱 |

**决策（2026-09-03 用户拍板）**：

- **A. rig 独立成 fast_llm，用 rig 自带的网络能力**（rig 本来就依赖 reqwest；不再从 http crate 借
  `client::shared()`，改成自建、注入 webpki-roots 的 reqwest Client）。代价是第二份网络底座与第二个
  tokio 运行时，接受。
- **B. s3 / webdav 进 fast_http**：它们就是 HTTP（签名 + XML）。不另起 fast_sync。
- **C. 字体解析 Dart 化，fast_font 不建**；graph / crypto 各自独立，接受体积增加。
  调研结论：Rust 侧只做两件事——name 表取 nameID 4（Unicode 记录，UTF-16BE）与 fvar 表取 wght 轴
  默认值 + 各命名实例的 wght。用 `dart:typed_data` 手写 SFNT 表目录 + name + fvar 解析约 80 行，
  已写原型并与 Rust 输出逐字对比：Dosis.ttf（VF）、SFNS.ttf / SFCompact.ttf（Apple 的多轴 VF，
  几百个实例）、Songti.ttc / Baskerville.ttc（TTC 取第 0 张脸、CJK 名字）、Noto OTF（CFF）、
  Arial / qweather-icons（无 fvar）**全部一致**；Skia.ttf 两边都拿不到 Unicode 名（只有 Mac Roman 记录），
  行为也一致。pub.dev 上只有 glyph_path（107 次下载）与 tief_fonts（6 次），不值得引依赖。
  落点：`moodiary_theme` 内一个 `font_tables.dart`，单测用仓内 Dosis.ttf。原型见附录。
- **D. moodiary_rust 删除**：包目录、`RustLib.init`、`_rustFacadeOwners` / `_rustFacadeRe` /
  `_rustDeepRe` / `_checkRustLayers`、`testing.dart` 一起走；将来真有业务 Rust 再建。

## 五、延迟初始化

每个包提供一个幂等入口：

```dart
abstract final class FastPress {
  static Future<void>? _init;
  static Future<void> ensureInitialized() =>
      FastPressLib.instance.initialized ? Future.value() : (_init ??= FastPressLib.init());
}
```

- FRB 的 `init` 二次调用会抛 `Should not initialize flutter_rust_bridge twice`，所以必须共用一个
  Future 防并发；`initialized` 是 FRB 2.13 `BaseEntrypoint` 自带的 getter。
- 消费方在入口处 `await`（导出服务的 `run`、助手会话的开场、图谱页的 initState…）。首次使用多付一次
  dlopen（几十毫秒），之后零开销。
- 启动路径只留 **fast_text**（搜索索引 / 迁移）与 **fast_crypto**（应用锁校验），其余全部推迟。
- fast_press 现在就能改：导出服务 `run` 开头 `await FastPress.ensureInitialized()`，`main.dart` 那句
  `FastPressLib.init()` 删掉，mobile 也就不必依赖 fast_press 了（`_nativePkgOwners` 里的「组合根例外」
  随之取消）。

## 六、分期（每期一个 PR，照 fast_press 的做法）

套路：`git mv` 保历史 → 单 crate（`api/` 是唯一 FRB 层 + 引擎模块）→ 复制 hook / about.toml /
rust-toolchain / Cargo.lock（从 moodiary_rust 那份复制，cargo 自动修剪，版本不漂）→ `gen-rust` →
消费方换 import → `_nativePkgOwners` / CI / licenses / CLAUDE.md。

1. **fast_http**（含 s3 / webdav）。最大的一块，也是解锁最多的：moodiary_http 的
   `RustHttpClient` / `RustHttpServer`、moodiary_sync 的 S3 / WebDAV 后端与 `lan_transfer_test` 一起切。
   落地后**用真实 .so 核一次体积**，再定 A。
2. **fast_llm**。assistant 整个出去；rig 的 reqwest 改为自建（注入 webpki-roots，
   Android 上 rustls-platform-verifier 会 panic）。此后 moodiary_rust 里不再有网络底座。
3. **fast_text**（text + hf_tokenizer + `testing.dart` 替身改名 `installFakeFastText`）。
   data / diary / assistant / ml 与 migration 测试切换。
4. **fast_crypto（裸 FFI 模板）**，然后 **fast_graph（裸 FFI）**、**fast_zip（FRB）**、**字体解析 Dart 化**（删 font crate 与 ttf-parser fork）。crypto 先做，把裸 FFI 的模板（hook / catch_unwind / Isolate.run / 测试）钉下来再复制给 graph。
5. **删 moodiary_rust**。`check_generated` 与 `task.dart` 里读 codegen 版本的锚点 `_rustPkgDir` 改成
   `_frbPkgDirs.first`；CI 的 rust job 改成对所有 `fast_*/rust` 循环；根 CLAUDE.md 的 Rust 一节重写。

## 七、FRB 还是裸 FFI（native_toolchain_rust 直连）

`native_toolchain_rust` 1.0.6 就是 `flutter_rust_bridge_hooks` 底下那一层：hook 里
`RustBuilder(assetName: 'src/ffi.dart', cratePath: 'rust', extraCargoEnvironmentVariables: …)`，
它把 cdylib 登记成 code asset，Dart 侧用 `@Native<…>(assetId: …)` 直接解析符号——**不用 dlopen、
不用 init**，天然就是延迟装载（首次调用才加载）。部署目标映射那段 hook 逻辑照抄现在的。

得到：每库省一份 FRB 运行时（实测地板 619 KB → 294 KB 量级），没有 tokio / 线程池，没有 codegen CLI
钉版本、content hash 闸门、freezed 那条链。
付出：`extern "C"` 手写（指针 + 长度进、out 指针出、配 free）；**每个入口 `catch_unwind`**（panic 越过
FFI 边界是 UB，现在是 FRB 替我们兜的）；Dart 侧类型转换手写（十来个函数不值得上 cbindgen + ffigen）；
耗时调用自己 `Isolate.run`（FRB 现在是线程池 + Future）；流式回调用 `NativeCallable.listener`。

逐包判定：

| 包 | 判定 | 理由 |
|---|---|---|
| fast_crypto | **裸 FFI，先做** | 五个同步函数，字节进字节出；文件加解密与 Argon2 走 `Isolate.run`。最适合当模板。 |
| fast_graph | **裸 FFI** | 现在是「后台线程逐帧推 `Vec<f32>`」。裸 FFI 有两条路：`NativeCallable.listener` 每帧回调，或改成 Dart 驱动的 `step(handle) → 帧` 同步 API 跑在 `Isolate.run` 里。推荐后者：帧率由 Dart 定、取消就是不再调用，反而比现在的 StreamSink 好控。 |
| fast_zip | 先 FRB | 有写入器句柄 + 取消令牌，裸 FFI 要 `Box::into_raw` 句柄 + `AtomicBool` 指针，可做但不急。 |
| fast_text | 先 FRB | 返回 `Vec<Vec<String>>` 要自定义序列化；但裸 FFI 后测试替身反而更干净（Dart 接口 + 假实现，不再 `initMock`）。 |
| fast_http / fast_llm / fast_press | FRB | async + 流 + Dart 回调（服务端 handler、工具分发），FRB 的主场。 |

裸 FFI 包的模板要点：`crate-type = ["cdylib", "staticlib"]`（iOS 静态链接）；`[profile.release]` 与
FRB 包同口径，`panic` 仍不要 abort，靠入口处 `catch_unwind` 转错误码；Dart 侧一个 `ffi.dart` 放
`@Native` 声明、一个门面类做 `Isolate.run` 与错误码 → 异常；`flutter test` 下 hook 同样会给宿主编
一份，不再需要 FRB 那套 `externalLibrary`。

## 八、拆完要立的规矩

- **跨包版本一致**：没有 `[workspace.dependencies]` 了，同一 crate 会在多个 `fast_*` 里各钉一次。
  加一条闸门（放 `check_generated.dart`）：所有 `fast_*/rust/Cargo.toml` 里同名 crate 的版本必须相等，
  `rust-toolchain.toml` 也一样。FRB / anyhow / tokio / reqwest 最容易漂。
- 每包 CI：clippy + test；每包一份 CLAUDE.md 记坑。
- `_nativePkgOwners` 只登记单 owner 的包；多 owner 的（text / crypto / zip）靠层规则就够。

## 九、体积预估

Android arm64、stripped、同一套 release profile：

| 实测项 | 字节 | 说明 |
|---|---:|---|
| 带 FRB 运行时的空壳库 | 619,472 | fast_press 的 api/ 原样保留、引擎换成 stub、只依赖 flutter_rust_bridge + anyhow；即 std + FRB（含 tokio）+ 十来个 wire 函数 |
| 空 cdylib（2026-08-20） | 294,144 | 不带 FRB |
| 拆 fast_press 的净增 | ≈ 2.9 MB | 45.8 → 15.6 + 33.1；大库之间重复的 regex / serde / flate2 / std 泛型实例化 |

估算：6 个库 × 0.6 MB 地板 ≈ 3.6 MB；fast_llm 自带网络底座 ≈ +2.5–3.5 MB；其余重复（regex 在
fast_text 与 fast_llm 之间、ring 在 fast_crypto 与两份 rustls 之间）≈ 0.5–1 MB。合计
**≈ +7 MB**，对 15.6 MiB 的现状约 +45%。第 1 期落地后用真实 .so 校准。

## 附录：字体解析 Dart 原型（与 Rust 逐字对比过）

```dart
/// SFNT 表目录：TTF / OTF（CFF）/ TTC（取第 0 张脸）。
Map<String, (int, int)> _tables(ByteData d) {
  var base = 0;
  if (d.getUint32(0) == 0x74746366) base = d.getUint32(12); // 'ttcf'
  final numTables = d.getUint16(base + 4);
  final out = <String, (int, int)>{};
  for (var i = 0; i < numTables; i++) {
    final r = base + 12 + i * 16;
    final tag = ascii.decode(d.buffer.asUint8List(d.offsetInBytes + r, 4));
    out[tag] = (d.getUint32(r + 8), d.getUint32(r + 12));
  }
  return out;
}

/// name 表：每个 nameID 取第一条 Unicode 记录（platform 0，或 platform 3 且 encoding 0/1/10），UTF-16BE。
Map<int, String> _names(ByteData d, (int, int) t) {
  final (off, _) = t;
  final count = d.getUint16(off + 2), strOff = off + d.getUint16(off + 4);
  final out = <int, String>{};
  for (var i = 0; i < count; i++) {
    final r = off + 6 + i * 12;
    final platform = d.getUint16(r), encoding = d.getUint16(r + 2);
    final nameId = d.getUint16(r + 6), len = d.getUint16(r + 8), so = d.getUint16(r + 10);
    final unicode = platform == 0 || (platform == 3 && (encoding == 0 || encoding == 1 || encoding == 10));
    if (!unicode || out.containsKey(nameId)) continue;
    final b = d.buffer.asUint8List(d.offsetInBytes + strOff + so, len);
    out[nameId] = String.fromCharCodes([for (var j = 0; j + 1 < len; j += 2) (b[j] << 8) | b[j + 1]]);
  }
  return out;
}

double _fixed(ByteData d, int o) => d.getInt32(o) / 65536.0;

/// fvar 表：wght 轴默认值 + 每个命名实例的 wght（与 Rust 的返回形状一致：{"default": …, "<subfamily>": …}）。
Map<String, double>? _wght(ByteData d, Map<String, (int, int)> tables, Map<int, String> names) {
  final t = tables['fvar'];
  if (t == null) return null;
  final (off, _) = t;
  final axesOff = off + d.getUint16(off + 4);
  final axisCount = d.getUint16(off + 8), axisSize = d.getUint16(off + 10);
  final instCount = d.getUint16(off + 12), instSize = d.getUint16(off + 14);
  var wghtIndex = -1;
  final out = <String, double>{};
  for (var i = 0; i < axisCount; i++) {
    final a = axesOff + i * axisSize;
    if (ascii.decode(d.buffer.asUint8List(d.offsetInBytes + a, 4)) == 'wght') {
      wghtIndex = i;
      out['default'] = _fixed(d, a + 8);
    }
  }
  final instOff = axesOff + axisCount * axisSize;
  for (var i = 0; i < instCount; i++) {
    final r = instOff + i * instSize;
    final subfamily = names[d.getUint16(r)];
    if (subfamily == null || wghtIndex < 0) continue;
    out[subfamily] = _fixed(d, r + 4 + wghtIndex * 4);
  }
  return out;
}
```
