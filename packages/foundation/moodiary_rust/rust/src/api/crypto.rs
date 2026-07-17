//! 加密原语：AES-256-GCM 对称加密；Argon2id 从用户密钥派生 AES key（同步对象唯一的 KDF）；
//! Argon2id 密码哈希工具（[Argon2]）目前未被同步层使用，保留供未来场景。

use anyhow::{anyhow, bail, Result};
use argon2::{PasswordHasher as _, PasswordVerifier as _};
use flutter_rust_bridge::frb;
use ring::{
    aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM},
    rand::{self, SecureRandom},
};

#[frb(opaque)]
pub struct Aes {}

impl Aes {
    /// 把 `user_key` 经 Argon2id 派生为 32 字节 key。参数缺省取 OWASP 推荐档
    /// （m=64 MiB, t=3, p=4，PC 上约 100 ms）；同步层解包 keyfile 时按文件所记
    /// 参数显式传入，未来升级强度不破坏旧 keyfile。同一 (salt, user_key, 参数)
    /// 输出确定。
    pub fn derive_key(
        salt: String,
        user_key: String,
        m_cost_kib: Option<u32>,
        t_cost: Option<u32>,
        p_cost: Option<u32>,
    ) -> Result<Vec<u8>> {
        const OUT_LEN: usize = 32;

        let params = argon2::Params::new(
            m_cost_kib.unwrap_or(64 * 1024),
            t_cost.unwrap_or(3),
            p_cost.unwrap_or(4),
            Some(OUT_LEN),
        )
        .map_err(|e| anyhow!("Argon2 参数无效: {}", e))?;
        let kdf = argon2::Argon2::new(
            argon2::Algorithm::Argon2id,
            argon2::Version::V0x13,
            params,
        );
        let mut out = [0u8; OUT_LEN];
        kdf.hash_password_into(user_key.as_bytes(), salt.as_bytes(), &mut out)
            .map_err(|e| anyhow!("Argon2id 派生密钥失败: {}", e))?;
        Ok(out.to_vec())
    }

    pub fn encrypt(key: Vec<u8>, mut data: Vec<u8>) -> Result<Vec<u8>> {
        let key = UnboundKey::new(&AES_256_GCM, &key).map_err(|_| anyhow!("密钥无效"))?;
        let key = LessSafeKey::new(key);

        let mut nonce_bytes = [0u8; 12];
        let rng = rand::SystemRandom::new();
        rng.fill(&mut nonce_bytes)
            .map_err(|_| anyhow!("随机数生成失败"))?;
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);

        data.reserve(16);
        key.seal_in_place_append_tag(nonce, Aad::empty(), &mut data)
            .map_err(|_| anyhow!("加密失败"))?;

        let mut encrypted_data = nonce_bytes.to_vec();
        encrypted_data.extend_from_slice(&data);
        Ok(encrypted_data)
    }

    pub fn decrypt(key: Vec<u8>, encrypted_data: Vec<u8>) -> Result<Vec<u8>> {
        if encrypted_data.len() < 12 + 16 {
            bail!("数据长度过短");
        }

        let key = UnboundKey::new(&AES_256_GCM, &key).map_err(|_| anyhow!("密钥无效"))?;
        let key = LessSafeKey::new(key);

        let (nonce_bytes, ciphertext_with_tag) = encrypted_data.split_at(12);
        let nonce =
            Nonce::try_assume_unique_for_key(nonce_bytes).map_err(|_| anyhow!("Nonce 无效"))?;

        let mut in_out = ciphertext_with_tag.to_vec();
        let decrypted_data = key
            .open_in_place(nonce, Aad::empty(), &mut in_out)
            .map_err(|_| anyhow!("解密失败"))?;

        Ok(decrypted_data.to_vec())
    }
}

#[frb(opaque)]
pub struct Argon2 {}

impl Argon2 {
    pub fn hash(password: String) -> Result<String> {
        let algo = argon2::Argon2::default();
        let hashed = algo
            .hash_password(password.as_bytes())
            .map_err(|e| anyhow!("Argon2 hash failed: {}", e))?;
        Ok(hashed.to_string())
    }

    pub fn verify(hash: String, password: String) -> Result<bool> {
        let parsed_hash = argon2::PasswordHash::new(&hash)
            .map_err(|e| anyhow!("Invalid hash format: {}", e))?;
        let algo = argon2::Argon2::default();
        match algo.verify_password(password.as_bytes(), &parsed_hash) {
            Ok(()) => Ok(true),
            Err(argon2::password_hash::Error::PasswordInvalid) => Ok(false),
            Err(e) => Err(anyhow!("Argon2 verify failed: {}", e)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn aes_derive_key_is_deterministic() {
        let salt = "moodiary".to_string();
        let user_key = "password456".to_string();
        let key1 = Aes::derive_key(salt.clone(), user_key.clone(), None, None, None).unwrap();
        let key2 = Aes::derive_key(salt, user_key, None, None, None).unwrap();
        assert_eq!(key1, key2);
        assert_eq!(key1.len(), 32);
    }

    #[test]
    fn aes_encrypt_decrypt_roundtrip() {
        let key =
            Aes::derive_key("moodiary".into(), "testpassword".into(), None, None, None).unwrap();
        let original_data = b"Hello Flutter Rust Bridge!".to_vec();
        let encrypted = Aes::encrypt(key.clone(), original_data.clone()).unwrap();
        let decrypted = Aes::decrypt(key, encrypted).unwrap();
        assert_eq!(original_data, decrypted);
    }

    #[test]
    fn aes_derive_key_rejects_short_salt() {
        let err = Aes::derive_key("short".into(), "any".into(), None, None, None).unwrap_err();
        assert!(err.to_string().contains("salt"));
    }

    #[test]
    fn aes_decrypt_short_input_fails() {
        let key = vec![0u8; 32];
        let bad_data = vec![1, 2, 3];
        assert!(Aes::decrypt(key, bad_data).is_err());
    }

    #[test]
    fn argon2_returns_ok() {
        let hashed = Argon2::hash("my_secure_password".into()).unwrap();
        assert!(!hashed.is_empty());
    }

    #[test]
    fn argon2_verify_correct() {
        let password = "my_secure_password".to_string();
        let hashed = Argon2::hash(password.clone()).unwrap();
        assert!(Argon2::verify(hashed, password).unwrap());
    }

    #[test]
    fn argon2_verify_wrong_fails() {
        let hashed = Argon2::hash("my_secure_password".into()).unwrap();
        assert!(!Argon2::verify(hashed, "incorrect_password".into()).unwrap());
    }
}
