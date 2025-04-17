#[cfg(test)]
mod aes_test {
    use crate::api::aes::AesEncryption;

    #[test]
    fn test_derive_key_consistency() {
        let salt = "salt123".to_string();
        let user_key = "password456".to_string();
        let key1 = AesEncryption::derive_key(salt.clone(), user_key.clone()).unwrap();
        let key2 = AesEncryption::derive_key(salt, user_key).unwrap();
        assert_eq!(key1, key2);
    }

    #[test]
    fn test_encrypt_decrypt() {
        let salt = "testsalt".to_string();
        let user_key = "testpassword".to_string();
        let key = AesEncryption::derive_key(salt, user_key).unwrap();

        let original_data = b"Hello Flutter Rust Bridge!".to_vec();
        let encrypted = AesEncryption::encrypt(key.clone(), original_data.clone()).unwrap();
        let decrypted = AesEncryption::decrypt(key, encrypted).unwrap();

        assert_eq!(original_data, decrypted);
    }

    #[test]
    fn test_decrypt_invalid_data() {
        let key = vec![0u8; 32]; // dummy key
        let bad_data = vec![1, 2, 3]; // too short

        let result = AesEncryption::decrypt(key, bad_data);
        assert!(result.is_err());
    }
}
