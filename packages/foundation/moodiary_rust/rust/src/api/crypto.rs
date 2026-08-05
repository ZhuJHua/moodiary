use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct Aes {}

impl Aes {
    pub fn derive_key(
        salt: String,
        user_key: String,
        m_cost_kib: Option<u32>,
        t_cost: Option<u32>,
        p_cost: Option<u32>,
    ) -> Result<Vec<u8>> {
        moodiary_crypto::aes::derive_key(&salt, &user_key, m_cost_kib, t_cost, p_cost)
    }

    pub fn encrypt(key: Vec<u8>, data: Vec<u8>) -> Result<Vec<u8>> {
        moodiary_crypto::aes::encrypt(key, data)
    }

    pub fn decrypt(key: Vec<u8>, encrypted_data: Vec<u8>) -> Result<Vec<u8>> {
        moodiary_crypto::aes::decrypt(key, encrypted_data)
    }
}

#[frb(opaque)]
pub struct Argon2 {}

impl Argon2 {
    pub fn hash(password: String) -> Result<String> {
        moodiary_crypto::password::hash(&password)
    }

    pub fn verify(hash: String, password: String) -> Result<bool> {
        moodiary_crypto::password::verify(&hash, &password)
    }
}
