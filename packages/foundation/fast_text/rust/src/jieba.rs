use anyhow::Result;
use jieba_rs::Jieba as JiebaInner;
use rust_stemmers::{Algorithm, Stemmer};
use std::sync::OnceLock;
use unicode_segmentation::UnicodeSegmentation;

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

pub struct Tokenizer {
    jieba: JiebaInner,
    stemmer: Stemmer,
}

struct Segment {
    text: String,
    is_cjk: bool,
}

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

static GLOBAL_TOKENIZER: OnceLock<Tokenizer> = OnceLock::new();

impl Tokenizer {
    /// 惰性建词典（约 100ms）。调用方都在 FRB 线程池上，不占启动路径。
    fn get() -> &'static Tokenizer {
        GLOBAL_TOKENIZER.get_or_init(|| Tokenizer {
            jieba: JiebaInner::new(),
            stemmer: Stemmer::create(Algorithm::English),
        })
    }

    fn stem_latin_segment(&self, segment: &str) -> Vec<String> {
        segment
            .unicode_words()
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

    /// 单篇路径：CJK 段的两种切分拆两条线程并行，压低单次延迟。批量走 tokenize_batch。
    pub fn tokenize(text: String) -> Result<TokenizeResult> {
        let tokenizer = Self::get();
        Ok(tokenizer.tokenize_one(&text, true))
    }

    /// 返回顺序与入参一一对应。篇内串行——若篇内再起线程，20k 篇会退化成数万次
    /// 线程创建，那正是逐篇调用的主要开销来源。
    pub fn tokenize_batch(texts: Vec<String>) -> Result<Vec<TokenizeResult>> {
        let tokenizer = Self::get();
        if texts.len() <= 1 {
            return Ok(texts
                .iter()
                .map(|t| tokenizer.tokenize_one(t, true))
                .collect());
        }

        let workers = std::thread::available_parallelism()
            .map_or(1, |n| n.get())
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
                    all_cfs.extend(cfs_handle.join().expect("cut_for_search thread panicked"));
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
                    .unicode_words()
                    .map(|w| w.to_lowercase())
                    .filter(|w| w.len() >= 2)
                    .collect()
            };
            all_cut.extend(tokens.clone());
            all_cfs.extend(tokens);
        }

        // 保留重复与出现序：词频（BM25 的 TF）由消费方（FTS5 / 统计）从重复次数得出。
        // 早期版本在这里做 HashSet 去重，导致全库 TF 恒为 1、词频饱和项退化成常数。
        TokenizeResult {
            cut: all_cut,
            cut_for_search: all_cfs,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
            (
                "今天天气很好，我去公园散步了",
                "今天天气/很/好/，/我/去/公园/散步/了",
            ),
            (
                "他说这个方案不太行，我们再想想别的办法",
                "他/说/这个/方案/不/太行/，/我们/再/想想/别的/办法",
            ),
            (
                "北京大学的研究生正在做自然语言处理",
                "北京大学/的/研究生/正在/做/自然语言/处理",
            ),
            (
                "我在上海南京路步行街买了一杯咖啡",
                "我/在/上海南京路/步行街/买/了/一杯/咖啡",
            ),
            ("百年孤独是一本很棒的小说", "百年孤独/是/一本/很棒/的/小说"),
            (
                "睡不着的夜里我写了一篇日记",
                "睡不着/的/夜里/我/写/了/一篇/日记",
            ),
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

    fn ensure_tokenizer() -> &'static Tokenizer {
        Tokenizer::get()
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
        let result = Tokenizer::tokenize("今天去了Starbucks，感觉coffee不错".into()).unwrap();
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
    fn tokenize_keeps_duplicates_for_tf() {
        ensure_tokenizer();
        let result = Tokenizer::tokenize("hello hello hello".into()).unwrap();
        let hello_count = result.cut.iter().filter(|t| t.as_str() == "hello").count();
        assert_eq!(hello_count, 3, "重复必须保留——词频（TF）由重复次数得出");
    }
}
