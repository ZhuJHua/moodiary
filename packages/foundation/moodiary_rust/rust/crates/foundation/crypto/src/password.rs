//! Argon2id 密码哈希（PHC 字符串，盐随机生成并写在串里）。应用锁 PIN 用它，
//! Dart 侧入口是 `AppLockPin`。同步的信封加密走的是 `aes::derive_key`，不是这里。

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
