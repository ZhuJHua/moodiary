use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use jieba_rs::Jieba as JiebaInner;
use rust_stemmers::{Algorithm, Stemmer};
use std::collections::{HashMap, HashSet};
use tokio::sync::OnceCell as AsyncOnceCell;
use unicode_segmentation::UnicodeSegmentation;

fn build_prefix_table(pattern: &[char]) -> Vec<usize> {
    let m = pattern.len();
    let mut prefix_table = vec![0; m];
    let mut j = 0;

    for i in 1..m {
        while j > 0 && pattern[i] != pattern[j] {
            j = prefix_table[j - 1];
        }
        if pattern[i] == pattern[j] {
            j += 1;
        }
        prefix_table[i] = j;
    }

    prefix_table
}

fn kmp_search(text: &str, pattern: &str) -> Vec<usize> {
    let text_chars: Vec<char> = text.chars().collect();
    let pattern_chars: Vec<char> = pattern.chars().collect();
    let m = pattern_chars.len();
    let prefix_table = build_prefix_table(&pattern_chars);
    let mut matches = Vec::new();
    let mut j = 0;

    for (i, &c) in text_chars.iter().enumerate() {
        while j > 0 && c != pattern_chars[j] {
            j = prefix_table[j - 1];
        }
        if c == pattern_chars[j] {
            j += 1;
        }
        if j == m {
            matches.push(i + 1 - m);
            j = prefix_table[j - 1];
        }
    }

    matches
}

#[frb(opaque)]
pub struct Kmp {}

impl Kmp {
    pub fn replace(text: String, replacements: HashMap<String, String>) -> String {
        if replacements.is_empty() {
            return text;
        }

        let mut match_entries: HashMap<usize, (&str, &str)> = HashMap::new();

        for (pattern, replacement) in &replacements {
            let matches = kmp_search(&text, pattern);
            for &index in &matches {
                if !match_entries.contains_key(&index)
                    || match_entries[&index].0.len() < pattern.len()
                {
                    match_entries.insert(index, (pattern, replacement));
                }
            }
        }

        let mut result = String::new();
        let mut last_index = 0;
        let mut match_entries: Vec<_> = match_entries.into_iter().collect();
        match_entries.sort_by_key(|&(index, _)| index);

        let text_chars: Vec<char> = text.chars().collect();
        for (index, (pattern, replacement)) in match_entries {
            let start_byte_index = text_chars[..index]
                .iter()
                .map(|c| c.len_utf8())
                .sum::<usize>();
            let end_byte_index = start_byte_index + pattern.len();

            if start_byte_index >= last_index {
                result.push_str(&text[last_index..start_byte_index]);
                result.push_str(replacement);
                last_index = end_byte_index;
            }
        }

        result.push_str(&text[last_index..]);
        result
    }

    pub fn find_all(text: &str, patterns: Vec<String>) -> Vec<String> {
        let mut matched_patterns = Vec::new();

        for pattern in &patterns {
            if !kmp_search(text, pattern).is_empty() {
                matched_patterns.push(pattern.clone());
            }
        }

        matched_patterns
    }
}

/// `cut`（高精度）和 `cut_for_search`（高召回）两组分词结果。
pub struct TokenizeResult {
    pub cut: Vec<String>,
    pub cut_for_search: Vec<String>,
}

#[inline]
fn is_cjk(c: char) -> bool {
    matches!(c,
        '\u{4E00}'..='\u{9FFF}'   |
        '\u{3400}'..='\u{4DBF}'   |
        '\u{20000}'..='\u{2A6DF}' |
        '\u{2A700}'..='\u{2B73F}' |
        '\u{2B740}'..='\u{2B81F}' |
        '\u{F900}'..='\u{FAFF}'   |
        '\u{2F800}'..='\u{2FA1F}'
    )
}

fn has_alphanumeric(s: &str) -> bool {
    s.chars().any(|c| c.is_alphanumeric())
}

#[frb(opaque)]
pub struct Tokenizer {
    jieba: JiebaInner,
    stemmer: Stemmer,
}

struct Segment {
    text: String,
    is_cjk: bool,
}

/// 按空白与 CJK/非 CJK 边界切段：CJK 段交给 jieba，其余走 unicode 词界 + 英文词干。
fn segment_text(text: &str) -> Vec<Segment> {
    let mut segments: Vec<Segment> = Vec::new();
    let mut current = String::new();
    let mut current_is_cjk: Option<bool> = None;

    for ch in text.chars() {
        if ch.is_whitespace() {
            if !current.is_empty() {
                segments.push(Segment {
                    text: current.clone(),
                    is_cjk: current_is_cjk.unwrap_or(false),
                });
                current.clear();
                current_is_cjk = None;
            }
            continue;
        }
        let ch_is_cjk = is_cjk(ch);
        if let Some(prev) = current_is_cjk
            && ch_is_cjk != prev
        {
            segments.push(Segment {
                text: current.clone(),
                is_cjk: prev,
            });
            current.clear();
        }
        current_is_cjk = Some(ch_is_cjk);
        current.push(ch);
    }
    if !current.is_empty() {
        segments.push(Segment {
            text: current,
            is_cjk: current_is_cjk.unwrap_or(false),
        });
    }

    segments
}

static GLOBAL_TOKENIZER: AsyncOnceCell<Tokenizer> = AsyncOnceCell::const_new();

#[frb(init)]
pub async fn init_tokenizer() {
    GLOBAL_TOKENIZER
        .get_or_init(|| async {
            tokio::task::spawn_blocking(|| Tokenizer {
                jieba: JiebaInner::new(),
                stemmer: Stemmer::create(Algorithm::English),
            })
            .await
            .expect("Tokenizer init panicked")
        })
        .await;
}

impl Tokenizer {
    fn get() -> Result<&'static Tokenizer> {
        GLOBAL_TOKENIZER
            .get()
            .context("Tokenizer is not initialized")
    }

    fn stem_latin_segment(&self, segment: &str) -> Vec<String> {
        segment
            .split_word_bounds()
            .filter(|w| has_alphanumeric(w))
            .map(|w| {
                let lower = w.to_lowercase();
                if lower.len() > 3 {
                    self.stemmer.stem(&lower).into_owned()
                } else {
                    lower
                }
            })
            .filter(|w| w.len() >= 2)
            .collect()
    }

    /// 单篇分词（交互路径：编辑保存、搜索框）。CJK 段的 cut 与 cut_for_search 拆两条
    /// 线程并行，压低单次延迟；批量请走 [`Tokenizer::tokenize_batch`]，它跨篇并行、
    /// 篇内串行，不会为每篇再起线程。
    pub fn tokenize(text: String) -> Result<TokenizeResult> {
        let tokenizer = Self::get()?;
        Ok(tokenizer.tokenize_one(&text, true))
    }

    /// 批量分词：一次过桥处理整批，跨篇并行铺满多核。全量重建索引 / 批量导入用。
    ///
    /// 返回顺序与入参一一对应。线程数取 `available_parallelism`（钳到批大小），
    /// 按步长分配任务；篇内串行——若篇内再起线程，20k 篇会退化成数万次线程创建，
    /// 那正是逐篇调用的主要开销来源。
    pub fn tokenize_batch(texts: Vec<String>) -> Result<Vec<TokenizeResult>> {
        let tokenizer = Self::get()?;
        if texts.len() <= 1 {
            return Ok(texts
                .iter()
                .map(|t| tokenizer.tokenize_one(t, true))
                .collect());
        }

        let workers = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(1)
            .min(texts.len());

        if workers <= 1 {
            return Ok(texts
                .iter()
                .map(|t| tokenizer.tokenize_one(t, false))
                .collect());
        }

        let texts = &texts;
        let mut slots: Vec<Option<TokenizeResult>> = (0..texts.len()).map(|_| None).collect();

        std::thread::scope(|scope| {
            let mut handles = Vec::with_capacity(workers);
            for w in 0..workers {
                handles.push(scope.spawn(move || {
                    let mut out: Vec<(usize, TokenizeResult)> = Vec::new();
                    let mut i = w;
                    while i < texts.len() {
                        out.push((i, tokenizer.tokenize_one(&texts[i], false)));
                        i += workers;
                    }
                    out
                }));
            }
            for handle in handles {
                for (i, result) in handle.join().expect("tokenize worker panicked") {
                    slots[i] = Some(result);
                }
            }
        });

        Ok(slots
            .into_iter()
            .map(|s| s.expect("every index assigned exactly once"))
            .collect())
    }

    /// 分词核心。[`pair_parallel`] 为真时把 CJK 段的两种切分放到两条线程上跑
    /// （单篇低延迟），为假时串行（批量路径已在更外层并行）。
    fn tokenize_one(&self, text: &str, pair_parallel: bool) -> TokenizeResult {
        let segments = segment_text(text);

        let cjk_segments: Vec<&str> = segments
            .iter()
            .filter(|s| s.is_cjk)
            .map(|s| s.text.as_str())
            .collect();

        let mut all_cut: Vec<String> = Vec::new();
        let mut all_cfs: Vec<String> = Vec::new();

        if !cjk_segments.is_empty() {
            let jieba = &self.jieba;
            let segs = &cjk_segments;
            let cut_all = || {
                let mut tokens = Vec::new();
                for seg in segs {
                    for word in jieba.cut(seg, true) {
                        tokens.push(word.word.to_string());
                    }
                }
                tokens
            };
            let cfs_all = || {
                let mut tokens = Vec::new();
                for seg in segs {
                    for word in jieba.cut_for_search(seg, true) {
                        tokens.push(word.word.to_string());
                    }
                }
                tokens
            };

            if pair_parallel {
                std::thread::scope(|scope| {
                    let cut_handle = scope.spawn(cut_all);
                    let cfs_handle = scope.spawn(cfs_all);
                    all_cut.extend(cut_handle.join().expect("cut thread panicked"));
                    all_cfs.extend(
                        cfs_handle.join().expect("cut_for_search thread panicked"),
                    );
                });
            } else {
                all_cut.extend(cut_all());
                all_cfs.extend(cfs_all());
            }
        }

        for seg in &segments {
            if seg.is_cjk {
                continue;
            }
            let tokens = if seg.text.is_ascii() {
                self.stem_latin_segment(&seg.text)
            } else {
                seg.text
                    .split_word_bounds()
                    .filter(|w| has_alphanumeric(w))
                    .map(|w| w.to_lowercase())
                    .filter(|w| w.len() >= 2)
                    .collect()
            };
            all_cut.extend(tokens.clone());
            all_cfs.extend(tokens);
        }

        let cut: Vec<String> = {
            let set: HashSet<String> = all_cut.into_iter().collect();
            set.into_iter().collect()
        };
        let cut_for_search: Vec<String> = {
            let set: HashSet<String> = all_cfs.into_iter().collect();
            set.into_iter().collect()
        };

        TokenizeResult {
            cut,
            cut_for_search,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// cut / cut_for_search 由 HashSet 收集，顺序本就不保证，比较前排序。
    fn sorted(r: &TokenizeResult) -> (Vec<String>, Vec<String>) {
        let mut a = r.cut.clone();
        let mut b = r.cut_for_search.clone();
        a.sort();
        b.sort();
        (a, b)
    }

    /// 分词黄金用例：锁住若干典型句子的切分结果。词表或 jieba 版本变动导致切分漂移时，
    /// 这里先红，而不是等到用户发现旧日记搜不到。
    #[test]
    fn segmentation_goldens() {
        let tk = ensure_tokenizer();
        const CASES: &[(&str, &str)] = &[
            ("今天天气很好，我去公园散步了", "今天天气/很/好/，/我/去/公园/散步/了"),
            ("他说这个方案不太行，我们再想想别的办法", "他/说/这个/方案/不/太行/，/我们/再/想想/别的/办法"),
            ("北京大学的研究生正在做自然语言处理", "北京大学/的/研究生/正在/做/自然语言/处理"),
            ("我在上海南京路步行街买了一杯咖啡", "我/在/上海南京路/步行街/买/了/一杯/咖啡"),
            ("百年孤独是一本很棒的小说", "百年孤独/是/一本/很棒/的/小说"),
            ("睡不着的夜里我写了一篇日记", "睡不着/的/夜里/我/写/了/一篇/日记"),
        ];
        for (text, expected) in CASES {
            let got: Vec<&str> = tk
                .jieba
                .cut(text, true)
                .into_iter()
                .map(|w| w.word)
                .collect();
            assert_eq!(got.join("/"), *expected, "分词漂移: {text}");
        }
    }

    #[test]
    fn tokenize_batch_matches_single_and_keeps_order() {
        let tk = ensure_tokenizer();
        let texts: Vec<String> = vec![
            "今天天气很好，我去公园散步了".into(),
            "".into(),
            "flutter and rust are cool".into(),
            "混合 mixed 中英文 content 一起".into(),
            "单字".into(),
            "重复的句子重复的句子重复的句子".into(),
            "   ".into(),
            "标点，。！？符号".into(),
        ];

        let batch = Tokenizer::tokenize_batch(texts.clone()).expect("batch");
        assert_eq!(batch.len(), texts.len());

        for (i, text) in texts.iter().enumerate() {
            let single = tk.tokenize_one(text, true);
            assert_eq!(
                sorted(&batch[i]),
                sorted(&single),
                "批量第 {i} 篇与逐篇结果不一致: {text:?}"
            );
        }
    }

    #[test]
    fn tokenize_batch_alignment_is_per_index() {
        ensure_tokenizer();
        // 每篇含唯一标记词，确认结果没有串位（步长分配 + 回填的正确性）。
        let texts: Vec<String> = (0..37)
            .map(|i| format!("唯一标记 marker{i} 后面是正文内容"))
            .collect();
        let batch = Tokenizer::tokenize_batch(texts).expect("batch");
        for (i, r) in batch.iter().enumerate() {
            let marker = format!("marker{i}");
            assert!(
                r.cut.contains(&marker),
                "第 {i} 篇缺少自己的标记 {marker}，结果串位了"
            );
        }
    }

    #[test]
    fn tokenize_batch_empty_input() {
        ensure_tokenizer();
        assert!(Tokenizer::tokenize_batch(vec![]).expect("batch").is_empty());
    }

    #[test]
    fn kmp_basic_match() {
        assert_eq!(kmp_search("ababcabcababc", "abc"), vec![2, 5, 10]);
    }

    #[test]
    fn kmp_replace_single() {
        let mut replacements = HashMap::new();
        replacements.insert("hello".into(), "hi".into());
        let result =
            Kmp::replace("hello world, hello rust".into(), replacements);
        assert_eq!(result, "hi world, hi rust");
    }

    #[test]
    fn kmp_replace_prefers_longer_match() {
        let mut replacements = HashMap::new();
        replacements.insert("abc".into(), "123".into());
        replacements.insert("bcd".into(), "234".into());
        let result = Kmp::replace("abcde".into(), replacements);
        assert_eq!(result, "123de");
    }

    #[test]
    fn kmp_replace_handles_unicode() {
        let mut replacements = HashMap::new();
        replacements.insert("世界".into(), "🌍".into());
        let result =
            Kmp::replace("你好世界，世界你好".into(), replacements);
        assert_eq!(result, "你好🌍，🌍你好");
    }

    #[test]
    fn kmp_find_all_filters() {
        let result = Kmp::find_all(
            "flutter and rust are cool",
            vec!["flutter".into(), "rust".into(), "dart".into()],
        );
        assert_eq!(result, vec!["flutter".to_string(), "rust".to_string()]);
    }

    #[test]
    fn kmp_find_all_empty_when_no_hit() {
        let result = Kmp::find_all(
            "no match here",
            vec!["something".into(), "nothing".into()],
        );
        assert!(result.is_empty());
    }

    #[test]
    fn kmp_replace_with_empty_map_is_identity() {
        let result = Kmp::replace("keep this".into(), HashMap::new());
        assert_eq!(result, "keep this");
    }

    /// 初始化全局分词器并返回它。测试并行执行，故统一走这一条路径——
    /// `init_tokenizer` 内部是 `get_or_init`，会把并发调用串行化；若另起一条
    /// 裸 `set` 的路径，两者会互相踩（set 失败 + get 到 None）。
    fn ensure_tokenizer() -> &'static Tokenizer {
        if GLOBAL_TOKENIZER.get().is_none() {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(init_tokenizer());
        }
        Tokenizer::get().expect("tokenizer initialized")
    }

    #[test]
    fn tokenize_cjk_returns_cut_and_cut_for_search() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("今天天气很好".into()).unwrap();
        assert!(result.cut.contains(&"今天天气".to_string()));
        assert!(result.cut.contains(&"很".to_string()));
        assert!(result.cut.contains(&"好".to_string()));
        assert!(result.cut_for_search.contains(&"今天".to_string()));
        assert!(result.cut_for_search.contains(&"天气".to_string()));
        assert!(result.cut_for_search.contains(&"今天天气".to_string()));
        assert!(result.cut_for_search.len() > result.cut.len());
    }

    #[test]
    fn tokenize_latin_stemming() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("Running and jumping".into()).unwrap();
        assert!(result.cut.iter().any(|t| t.starts_with("run")));
        assert!(result.cut.iter().any(|t| t.starts_with("jump")));
        assert_eq!(result.cut.len(), result.cut_for_search.len());
    }

    #[test]
    fn tokenize_mixed_language() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize(
            "今天去了Starbucks，感觉coffee不错".into(),
        )
        .unwrap();
        assert!(result.cut.contains(&"今天".to_string()));
        assert!(result.cut.contains(&"感觉".to_string()));
        assert!(result.cut.contains(&"不错".to_string()));
        assert!(result.cut.iter().any(|t| t.contains("starbucks")));
        assert!(result.cut.iter().any(|t| t.starts_with("coffe")));
    }

    #[test]
    fn tokenize_short_latin_words_filtered() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("I am a go".into()).unwrap();
        assert!(!result.cut.iter().any(|t| t == "i"));
        assert!(!result.cut.iter().any(|t| t == "a"));
        assert!(result.cut.iter().any(|t| t == "am" || t == "go"));
    }

    #[test]
    fn tokenize_empty_string() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("".into()).unwrap();
        assert!(result.cut.is_empty());
        assert!(result.cut_for_search.is_empty());
    }

    #[test]
    fn tokenize_punctuation_only() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("!@#$%^&*()".into()).unwrap();
        assert!(result.cut.is_empty());
        assert!(result.cut_for_search.is_empty());
    }

    #[test]
    fn tokenize_deduplication() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("hello hello hello".into()).unwrap();
        let hello_count = result.cut.iter().filter(|t| t.as_str() == "hello").count();
        assert_eq!(hello_count, 1);
    }
}
