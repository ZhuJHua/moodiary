use anyhow::Result;

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

pub fn aes_encrypt_file(
    key: Vec<u8>,
    in_path: String,
    out_path: String,
    prefix: Vec<u8>,
) -> Result<()> {
    crate::aes::encrypt_file(key, &in_path, &out_path, &prefix)
}

pub fn aes_decrypt_file(
    key: Vec<u8>,
    in_path: String,
    out_path: String,
    skip_prefix: u32,
) -> Result<()> {
    crate::aes::decrypt_file(key, &in_path, &out_path, u64::from(skip_prefix))
}

pub fn argon2_hash(password: String) -> Result<String> {
    crate::password::hash(&password)
}

pub fn argon2_verify(hash: String, password: String) -> Result<bool> {
    crate::password::verify(&hash, &password)
}
