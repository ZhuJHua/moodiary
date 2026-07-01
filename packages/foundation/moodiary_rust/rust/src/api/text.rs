use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use jieba_rs::{Jieba as JiebaInner, KeywordExtract, TextRank, TfIdf};
use once_cell::sync::OnceCell;
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

#[derive(Debug, Clone)]
#[frb(opaque)]
pub struct JiebaKeyword {
    pub keyword: String,
    pub weight: f64,
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
    tfidf: OnceCell<TfIdf>,
    text_rank: OnceCell<TextRank>,
}

static GLOBAL_TOKENIZER: AsyncOnceCell<Tokenizer> = AsyncOnceCell::const_new();

#[frb(init)]
pub async fn init_tokenizer() {
    GLOBAL_TOKENIZER
        .get_or_init(|| async {
            tokio::task::spawn_blocking(|| Tokenizer {
                jieba: JiebaInner::new(),
                stemmer: Stemmer::create(Algorithm::English),
                tfidf: OnceCell::new(),
                text_rank: OnceCell::new(),
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

    /// 同时返回 `cut` 和 `cut_for_search` 两组分词结果。
    /// CJK 段两种分词并发执行；非 CJK 段两组共享结果。
    pub fn tokenize(text: String) -> Result<TokenizeResult> {
        let tokenizer = Self::get()?;

        struct Segment {
            text: String,
            is_cjk: bool,
        }
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

        let mut all_cut: Vec<String> = Vec::new();
        let mut all_cfs: Vec<String> = Vec::new();

        let cjk_segments: Vec<&str> = segments
            .iter()
            .filter(|s| s.is_cjk)
            .map(|s| s.text.as_str())
            .collect();

        if !cjk_segments.is_empty() {
            let jieba = &tokenizer.jieba;
            let segs = &cjk_segments;

            std::thread::scope(|scope| {
                let cut_handle = scope.spawn(|| {
                    let mut tokens = Vec::new();
                    for seg in segs {
                        for word in jieba.cut(seg, true) {
                            tokens.push(word.word.to_string());
                        }
                    }
                    tokens
                });

                let cfs_handle = scope.spawn(|| {
                    let mut tokens = Vec::new();
                    for seg in segs {
                        for word in jieba.cut_for_search(seg, true) {
                            tokens.push(word.word.to_string());
                        }
                    }
                    tokens
                });

                all_cut.extend(cut_handle.join().expect("cut thread panicked"));
                all_cfs.extend(cfs_handle.join().expect("cut_for_search thread panicked"));
            });
        }

        for seg in &segments {
            if seg.is_cjk {
                continue;
            }
            let tokens = if seg.text.is_ascii() {
                tokenizer.stem_latin_segment(&seg.text)
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

        Ok(TokenizeResult {
            cut,
            cut_for_search,
        })
    }

    pub fn extract_keywords_tfidf(
        text: String,
        top_k: usize,
        allowed_pos: Vec<String>,
    ) -> Result<Vec<JiebaKeyword>> {
        let tokenizer = Self::get()?;
        let tfidf = tokenizer
            .tfidf
            .get_or_try_init(|| std::result::Result::<_, anyhow::Error>::Ok(TfIdf::default()))
            .context("Failed to initialize TF-IDF")?;
        let keywords = tfidf.extract_keywords(&tokenizer.jieba, &text, top_k, allowed_pos);
        Ok(Self::convert_keywords(keywords))
    }

    pub fn extract_keywords_text_rank(
        text: String,
        top_k: usize,
        allowed_pos: Vec<String>,
    ) -> Result<Vec<JiebaKeyword>> {
        let tokenizer = Self::get()?;
        let text_rank = tokenizer
            .text_rank
            .get_or_try_init(|| std::result::Result::<_, anyhow::Error>::Ok(TextRank::default()))
            .context("Failed to initialize TextRank")?;
        let keywords = text_rank.extract_keywords(&tokenizer.jieba, &text, top_k, allowed_pos);
        Ok(Self::convert_keywords(keywords))
    }

    fn convert_keywords(keywords: Vec<jieba_rs::Keyword>) -> Vec<JiebaKeyword> {
        keywords
            .into_iter()
            .map(|k| JiebaKeyword {
                keyword: k.keyword,
                weight: k.weight,
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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

    fn ensure_tokenizer() {
        if GLOBAL_TOKENIZER.get().is_none() {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(init_tokenizer());
        }
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
