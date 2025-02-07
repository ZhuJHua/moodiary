use anyhow::{anyhow, bail, Result};
use flutter_rust_bridge::frb;
use ring::{
    aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM},
    pbkdf2,
    rand::{self, SecureRandom},
};
use std::{num::NonZeroU32, vec::Vec};

#[frb(opaque)]
pub struct AesEncryption;

impl AesEncryption {
    pub fn derive_key(salt: String, user_key: String) -> Result<Vec<u8>> {
        let mut result = [0u8; 32];
        pbkdf2::derive(
            pbkdf2::PBKDF2_HMAC_SHA256,
            NonZeroU32::new(100_000).unwrap(),
            salt.as_bytes(),
            user_key.as_bytes(),
            &mut result,
        );
        Ok(result.to_vec())
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
