//! Argon2id 密码哈希。目前同步层未使用，保留供未来场景（应用锁等）。

use anyhow::{Result, anyhow};
use argon2::{PasswordHasher as _, PasswordVerifier as _};

pub fn hash(password: &str) -> Result<String> {
    let algo = argon2::Argon2::default();
    let hashed = algo
        .hash_password(password.as_bytes())
        .map_err(|e| anyhow!("Argon2 hash failed: {}", e))?;
    Ok(hashed.to_string())
}

pub fn verify(hash: &str, password: &str) -> Result<bool> {
    let parsed_hash =
        argon2::PasswordHash::new(hash).map_err(|e| anyhow!("Invalid hash format: {}", e))?;
    let algo = argon2::Argon2::default();
    match algo.verify_password(password.as_bytes(), &parsed_hash) {
        Ok(()) => Ok(true),
        Err(argon2::password_hash::Error::PasswordInvalid) => Ok(false),
        Err(e) => Err(anyhow!("Argon2 verify failed: {}", e)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_returns_ok() {
        assert!(!hash("my_secure_password").unwrap().is_empty());
    }

    #[test]
    fn verify_correct() {
        let hashed = hash("my_secure_password").unwrap();
        assert!(verify(&hashed, "my_secure_password").unwrap());
    }

    #[test]
    fn verify_wrong_fails() {
        let hashed = hash("my_secure_password").unwrap();
        assert!(!verify(&hashed, "incorrect_password").unwrap());
    }
}
