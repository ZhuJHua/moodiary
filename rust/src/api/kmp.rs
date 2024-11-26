use flutter_rust_bridge::frb;
use std::collections::HashMap;

pub fn build_prefix_table(pattern: &str) -> Vec<usize> {
    let m = pattern.len();
    let mut prefix_table = vec![0; m];
    let mut j = 0;

    for i in 1..m {
        while j > 0 && pattern.chars().nth(i) != pattern.chars().nth(j) {
            j = prefix_table[j - 1];
        }
        if pattern.chars().nth(i) == pattern.chars().nth(j) {
            j += 1;
        }
        prefix_table[i] = j;
    }

    prefix_table
}

pub fn kmp_search(text: &str, pattern: &str) -> Vec<usize> {
    let m = pattern.len();
    let prefix_table = build_prefix_table(pattern);
    let mut matches = Vec::new();
    let mut j = 0;

    for (i, c) in text.chars().enumerate() {
        while j > 0 && Some(c) != pattern.chars().nth(j) {
            j = prefix_table[j - 1];
        }
        if Some(c) == pattern.chars().nth(j) {
            j += 1;
        }
        if j == m {
            matches.push(i + 1 - m); // 添加匹配的起始索引
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
                    // 确保在相同索引位置，优先使用较长的模式
                    match_entries.insert(index, (pattern, replacement));
                }
            }
        }

        let mut result = String::new();
        let mut last_index = 0;

        let mut match_entries: Vec<_> = match_entries.into_iter().collect();
        match_entries.sort_by_key(|&(index, _)| index);

        for (index, (pattern, replacement)) in match_entries {
            if index >= last_index {
                result.push_str(&text[last_index..index]);
                result.push_str(replacement);
                last_index = index + pattern.len();
            }
        }

        result.push_str(&text[last_index..]);
        result
    }
}
