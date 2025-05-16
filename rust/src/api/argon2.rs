use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct Argon2Rs;

impl Argon2Rs {
    pub fn hash_password(password: String) -> Option<String> {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();

        argon2
            .hash_password(password.as_bytes(), &salt)
            .map(|hashed_password| hashed_password.to_string())
            .ok()
    }
    pub fn verify_password(hash: String, password: String) -> bool {
        let parsed_hash = argon2::PasswordHash::new(&hash).unwrap();
        let argon2 = argon2::Argon2::default();
        argon2
            .verify_password(password.as_bytes(), &parsed_hash)
            .is_ok()
    }
}
