//! AES-256-GCM 对称加密，以及同步对象唯一的 KDF（Argon2id 派生 AES key）。

use anyhow::{Result, anyhow, bail};
use ring::{
    aead::{AES_256_GCM, Aad, LessSafeKey, MAX_TAG_LEN, NONCE_LEN, Nonce, UnboundKey},
    rand::{self, SecureRandom},
};
use std::io::{Read, Seek, Write};

/// 缺省参数取 OWASP 推荐档（m=64 MiB, t=3, p=4，PC 上约 100 ms）。同步层解包 keyfile
/// 时按文件所记参数显式传入，这样升级强度不会破坏旧 keyfile。
pub fn derive_key(
    salt: &str,
    user_key: &str,
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
    let kdf = argon2::Argon2::new(argon2::Algorithm::Argon2id, argon2::Version::V0x13, params);
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

pub fn decrypt(key: Vec<u8>, mut encrypted_data: Vec<u8>) -> Result<Vec<u8>> {
    if encrypted_data.len() < NONCE_LEN + MAX_TAG_LEN {
        bail!("数据长度过短");
    }

    let key = UnboundKey::new(&AES_256_GCM, &key).map_err(|_| anyhow!("密钥无效"))?;
    let key = LessSafeKey::new(key);

    let nonce = Nonce::try_assume_unique_for_key(&encrypted_data[..NONCE_LEN])
        .map_err(|_| anyhow!("Nonce 无效"))?;

    // open_within 就是为「前缀 + 密文 + tag」这种布局准备的：原地解密并把明文左移到
    // 开头，省掉「复制密文」与「复制明文」两趟全载荷拷贝。
    let plain_len = key
        .open_within(nonce, Aad::empty(), &mut encrypted_data, NONCE_LEN..)
        .map_err(|_| anyhow!("解密失败"))?
        .len();
    encrypted_data.truncate(plain_len);
    Ok(encrypted_data)
}

/// 字节布局与 [encrypt] 一致（`prefix || nonce || 密文 || tag`），两条路互通。
/// 做不到真流式：GCM 的 tag 覆盖整条消息，改分块封装就读不了历史数据。
pub fn encrypt_file(key: Vec<u8>, in_path: &str, out_path: &str, prefix: &[u8]) -> Result<()> {
    let key = UnboundKey::new(&AES_256_GCM, &key).map_err(|_| anyhow!("密钥无效"))?;
    let key = LessSafeKey::new(key);

    let meta = std::fs::metadata(in_path)?;
    let mut data = Vec::with_capacity(meta.len() as usize + 16);
    std::fs::File::open(in_path)?.read_to_end(&mut data)?;

    let mut nonce_bytes = [0u8; 12];
    rand::SystemRandom::new()
        .fill(&mut nonce_bytes)
        .map_err(|_| anyhow!("随机数生成失败"))?;
    key.seal_in_place_append_tag(
        Nonce::assume_unique_for_key(nonce_bytes),
        Aad::empty(),
        &mut data,
    )
    .map_err(|_| anyhow!("加密失败"))?;

    let mut out = std::io::BufWriter::new(std::fs::File::create(out_path)?);
    out.write_all(prefix)?;
    out.write_all(&nonce_bytes)?;
    out.write_all(&data)?;
    out.flush()?;
    Ok(())
}

/// [skip_prefix] 是 [encrypt_file] 写入的 prefix 长度，直接 seek 掉，不产生额外副本。
pub fn decrypt_file(key: Vec<u8>, in_path: &str, out_path: &str, skip_prefix: u64) -> Result<()> {
    let key = UnboundKey::new(&AES_256_GCM, &key).map_err(|_| anyhow!("密钥无效"))?;
    let key = LessSafeKey::new(key);

    let mut file = std::fs::File::open(in_path)?;
    file.seek(std::io::SeekFrom::Start(skip_prefix))?;
    let mut data = Vec::new();
    file.read_to_end(&mut data)?;
    if data.len() < 12 + 16 {
        bail!("数据长度过短");
    }

    let (nonce_bytes, body) = data.split_at_mut(12);
    let nonce = Nonce::try_assume_unique_for_key(nonce_bytes).map_err(|_| anyhow!("Nonce 无效"))?;
    let plain_len = key
        .open_in_place(nonce, Aad::empty(), body)
        .map_err(|_| anyhow!("解密失败"))?
        .len();

    let mut out = std::io::BufWriter::new(std::fs::File::create(out_path)?);
    out.write_all(&body[..plain_len])?;
    out.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derive_key_is_deterministic() {
        let key1 = derive_key("moodiary", "password456", None, None, None).unwrap();
        let key2 = derive_key("moodiary", "password456", None, None, None).unwrap();
        assert_eq!(key1, key2);
        assert_eq!(key1.len(), 32);
    }

    #[test]
    fn encrypt_decrypt_roundtrip() {
        let key = derive_key("moodiary", "testpassword", None, None, None).unwrap();
        let original_data = b"Hello Flutter Rust Bridge!".to_vec();
        let encrypted = encrypt(key.clone(), original_data.clone()).unwrap();
        let decrypted = decrypt(key, encrypted).unwrap();
        assert_eq!(original_data, decrypted);
    }

    #[test]
    fn derive_key_rejects_short_salt() {
        let err = derive_key("short", "any", None, None, None).unwrap_err();
        assert!(err.to_string().contains("salt"));
    }

    #[test]
    fn encrypt_file_matches_in_memory_format() {
        let key = derive_key("moodiary", "filepassword", None, None, None).unwrap();
        let dir = std::env::temp_dir().join(format!("moodiary-aes-file-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("plain.bin");
        let enc = dir.join("enc.bin");
        let dec = dir.join("dec.bin");
        let payload = vec![7u8; 300 * 1024];
        std::fs::write(&src, &payload).unwrap();

        let magic = b"MD-ENC-V1\n";
        encrypt_file(
            key.clone(),
            src.to_str().unwrap(),
            enc.to_str().unwrap(),
            magic,
        )
        .unwrap();

        // 文件版写出的密文，去掉 magic 后必须能被内存版解开——两条路互通。
        let on_disk = std::fs::read(&enc).unwrap();
        assert_eq!(&on_disk[..magic.len()], magic);
        assert_eq!(
            decrypt(key.clone(), on_disk[magic.len()..].to_vec()).unwrap(),
            payload
        );

        decrypt_file(
            key,
            enc.to_str().unwrap(),
            dec.to_str().unwrap(),
            magic.len() as u64,
        )
        .unwrap();
        assert_eq!(std::fs::read(&dec).unwrap(), payload);

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn decrypt_file_reads_what_in_memory_encrypt_wrote() {
        let key = derive_key("moodiary", "interop", None, None, None).unwrap();
        let dir = std::env::temp_dir().join(format!("moodiary-aes-interop-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let enc = dir.join("enc.bin");
        let dec = dir.join("dec.bin");
        let payload = b"legacy object written by the in-memory path".to_vec();

        let mut bytes = b"MD-ENC-V1\n".to_vec();
        bytes.extend_from_slice(&encrypt(key.clone(), payload.clone()).unwrap());
        std::fs::write(&enc, &bytes).unwrap();

        decrypt_file(key, enc.to_str().unwrap(), dec.to_str().unwrap(), 10).unwrap();
        assert_eq!(std::fs::read(&dec).unwrap(), payload);

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn decrypt_short_input_fails() {
        assert!(decrypt(vec![0u8; 32], vec![1, 2, 3]).is_err());
    }
}
