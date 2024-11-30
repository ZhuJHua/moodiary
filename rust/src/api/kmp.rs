use flutter_rust_bridge::frb;
use std::collections::HashMap;

pub fn build_prefix_table(pattern: &[char]) -> Vec<usize> {
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

pub fn kmp_search(text: &str, pattern: &str) -> Vec<usize> {
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
pub struct Kmp;

impl Kmp {
    pub fn replace_with_kmp(text: String, replacements: HashMap<String, String>) -> String {
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

    pub fn find_matches(text: &str, patterns: Vec<String>) -> Vec<String> {
        let mut matched_patterns = Vec::new();

        for pattern in &patterns {
            if !kmp_search(text, pattern).is_empty() {
                matched_patterns.push(pattern.clone());
            }
        }

        matched_patterns
    }
}
