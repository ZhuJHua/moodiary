#[cfg(test)]
mod kmp_test {
    use crate::api::kmp::{kmp_search, Kmp};
    use std::collections::HashMap;

    #[test]
    fn test_kmp_basic_match() {
        let text = "ababcabcababc";
        let pattern = "abc";
        let matches = kmp_search(text, pattern);
        assert_eq!(matches, vec![2, 5, 10]);
    }

    #[test]
    fn test_replace_with_kmp_single() {
        let text = "hello world, hello rust";
        let mut replacements = HashMap::new();
        replacements.insert("hello".to_string(), "hi".to_string());

        let result = Kmp::replace_with_kmp(text.to_string(), replacements);
        assert_eq!(result, "hi world, hi rust");
    }

    #[test]
    fn test_replace_with_kmp_multiple_overlap() {
        let text = "abcde";
        let mut replacements = HashMap::new();
        replacements.insert("abc".to_string(), "123".to_string());
        replacements.insert("bcd".to_string(), "234".to_string());

        let result = Kmp::replace_with_kmp(text.to_string(), replacements);
        // 应优先替换更长的匹配，从左到右，“abc”会匹配成功，然后跳过“bcd”
        assert_eq!(result, "123de");
    }

    #[test]
    fn test_replace_with_kmp_unicode() {
        let text = "你好世界，世界你好";
        let mut replacements = HashMap::new();
        replacements.insert("世界".to_string(), "🌍".to_string());

        let result = Kmp::replace_with_kmp(text.to_string(), replacements);
        assert_eq!(result, "你好🌍，🌍你好");
    }

    #[test]
    fn test_find_matches() {
        let text = "flutter and rust are cool";
        let patterns = vec![
            "flutter".to_string(),
            "rust".to_string(),
            "dart".to_string(),
        ];
        let result = Kmp::find_matches(text, patterns);
        assert_eq!(result, vec!["flutter".to_string(), "rust".to_string()]);
    }

    #[test]
    fn test_find_matches_empty() {
        let text = "no match here";
        let patterns = vec!["something".to_string(), "nothing".to_string()];
        let result = Kmp::find_matches(text, patterns);
        assert!(result.is_empty());
    }

    #[test]
    fn test_empty_replacements() {
        let text = "keep this";
        let replacements = HashMap::new();
        let result = Kmp::replace_with_kmp(text.to_string(), replacements);
        assert_eq!(result, "keep this");
    }
}
