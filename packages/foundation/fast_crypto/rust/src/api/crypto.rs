//! 全部跑在 FRB 线程池上（不标 sync）：Argon2 派生与整文件加解密都是几十毫秒起的活。

use anyhow::Result;

/// Argon2id 派生 32 字节密钥。成本参数不传用默认值（64 MiB / 3 / 4）。
pub fn aes_derive_key(
    salt: String,
    user_key: String,
    m_cost_kib: Option<u32>,
    t_cost: Option<u32>,
    p_cost: Option<u32>,
) -> Result<Vec<u8>> {
    crate::aes::derive_key(&salt, &user_key, m_cost_kib, t_cost, p_cost)
}

pub fn aes_encrypt(key: Vec<u8>, data: Vec<u8>) -> Result<Vec<u8>> {
    crate::aes::encrypt(key, data)
}

pub fn aes_decrypt(key: Vec<u8>, encrypted_data: Vec<u8>) -> Result<Vec<u8>> {
    crate::aes::decrypt(key, encrypted_data)
}

/// 整文件加密，产物以 `prefix`（魔数）开头。
pub fn aes_encrypt_file(
    key: Vec<u8>,
    in_path: String,
    out_path: String,
    prefix: Vec<u8>,
) -> Result<()> {
    crate::aes::encrypt_file(key, &in_path, &out_path, &prefix)
}

/// 整文件解密，跳过开头 `skip_prefix` 个字节的魔数（u32 就够：Dart 侧拿 int 不用 BigInt）。
pub fn aes_decrypt_file(
    key: Vec<u8>,
    in_path: String,
    out_path: String,
    skip_prefix: u32,
) -> Result<()> {
    crate::aes::decrypt_file(key, &in_path, &out_path, u64::from(skip_prefix))
}

/// Argon2id 密码哈希（PHC 串）。
pub fn argon2_hash(password: String) -> Result<String> {
    crate::password::hash(&password)
}

pub fn argon2_verify(hash: String, password: String) -> Result<bool> {
    crate::password::verify(&hash, &password)
}
