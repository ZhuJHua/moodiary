# fast_tokenizer

分词：jieba + stemmer + CJK 分段（`jieba.rs`，搜索索引 / 关键词）与 HF tokenizer.json 封装
（`hf.rs`，ONNX 推理侧；WordPiece / SentencePiece / BPE 通吃）。自带 FRB（入口类 `FastTokenizerLib`）
与原生库 **libfasttokenizer**。2026-09-03 从旧 moodiary_rust 的 `text` + `hf_tokenizer` 两个 crate 拆出来（曾叫 fast_text，同日改名）。

- 多个消费方（data / diary / assistant / ml），不进 `_nativePkgOwners`。
- **启动时装载**（`main.dart` 的 `FastTokenizer.ensureInitialized()`）：搜索索引、迁移、心情建议都要它，
  不做延迟；`ensureInitialized` 仍是幂等的，ml 的两个后端在 `HfTokenizer.fromFile` 前也各 await 一次。
- **宿主测试用 `testing.dart`**：`installFakeFastTokenizer(tokenize)` 经 `FastTokenizerLib.initMock` 只桩掉
  分词，其余调用抛 UnimplementedError；生产代码不许 import（`check_layers` 守着）。
- jieba 词典（约 100ms）在首次分词时惰性建，调用方都在 FRB 线程池上，不占启动路径。
  批量分词走 `tokenize_batch`（实测比逐条快 6 倍）。
- HF tokenizer 关掉 `onig`（避 C 依赖），`unstable_wasm` 只为激活 fancy-regex 引擎；
  `tests/fixtures/wordpiece_tokenizer.json` 是单测夹具。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**；改了 `rust/Cargo.toml` 依赖必跑
  `dart tool/task.dart licenses`。
