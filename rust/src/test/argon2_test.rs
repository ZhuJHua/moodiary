#[cfg(test)]
mod argon2_test {
    use crate::api::argon2::Argon2Rs;
    #[test]
    fn test_hash_password() {
        let password = "my_secure_password".to_string();

        let hashed_password = Argon2Rs::hash_password(password.clone());

        assert!(hashed_password.is_some());
        assert!(!hashed_password.unwrap().is_empty());
    }

    #[test]
    fn test_verify_password_success() {
        let password = "my_secure_password".to_string();

        let hashed_password = Argon2Rs::hash_password(password.clone()).unwrap();

        let is_verified = Argon2Rs::verify_password(hashed_password, password);

        assert!(is_verified);
    }

    #[test]
    fn test_verify_password_failure() {
        let password = "my_secure_password".to_string();
        let wrong_password = "incorrect_password".to_string();

        let hashed_password = Argon2Rs::hash_password(password.clone()).unwrap();

        let is_verified = Argon2Rs::verify_password(hashed_password, wrong_password);

        assert!(!is_verified);
    }
}
