//! C ABI 门面：本 crate 唯一带 `unsafe` 的地方。约定——
//! * 输入一律「指针 + 长度」（字符串是 UTF-8 字节），Dart 侧 calloc、调用后自己释放；
//! * 输出经 [`FfiBuf`] 回传：返回 0 时是载荷，非 0 时是 UTF-8 错误信息（1 = 业务错误，
//!   2 = panic）；两种情况都由 Dart 用 [`fastcrypto_buf_free`] 归还；
//! * 每个入口 `catch_unwind`：panic 越过 FFI 边界是 UB，这里把它变成错误码。

use std::panic::{AssertUnwindSafe, catch_unwind};

use anyhow::Result;

/// Rust 堆上的一段字节，所有权交给 Dart，由 [`fastcrypto_buf_free`] 归还。
#[repr(C)]
pub struct FfiBuf {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

impl FfiBuf {
    fn from_vec(v: Vec<u8>) -> Self {
        let mut v = std::mem::ManuallyDrop::new(v);
        FfiBuf {
            ptr: v.as_mut_ptr(),
            len: v.len(),
            cap: v.capacity(),
        }
    }
}

/// # Safety
/// 三个值必须来自本库某次调用写出的 [`FfiBuf`]，且只归还一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_buf_free(ptr: *mut u8, len: usize, cap: usize) {
    if ptr.is_null() {
        return;
    }
    drop(unsafe { Vec::from_raw_parts(ptr, len, cap) });
}

/// # Safety
/// `ptr` 为空或 `len` 为 0 视为空切片；否则 `ptr` 必须指向至少 `len` 字节。
unsafe fn bytes<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    if ptr.is_null() || len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(ptr, len) }
    }
}

/// # Safety
/// 同 [`bytes`]。
unsafe fn text<'a>(ptr: *const u8, len: usize) -> Result<&'a str> {
    Ok(std::str::from_utf8(unsafe { bytes(ptr, len) })?)
}

fn run(out: *mut FfiBuf, f: impl FnOnce() -> Result<Vec<u8>>) -> i32 {
    let (code, payload) = match catch_unwind(AssertUnwindSafe(f)) {
        Ok(Ok(v)) => (0, v),
        Ok(Err(e)) => (1, e.to_string().into_bytes()),
        Err(p) => {
            let msg = p
                .downcast_ref::<&str>()
                .map(|s| (*s).to_owned())
                .or_else(|| p.downcast_ref::<String>().cloned())
                .unwrap_or_else(|| "unknown panic".to_owned());
            (2, format!("panic: {msg}").into_bytes())
        }
    };
    if !out.is_null() {
        unsafe { out.write(FfiBuf::from_vec(payload)) };
    }
    code
}

/// Argon2id 派生 32 字节密钥。三个成本参数传 0 表示用默认值。
///
/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_aes_derive_key(
    salt: *const u8,
    salt_len: usize,
    user_key: *const u8,
    user_key_len: usize,
    m_cost_kib: u32,
    t_cost: u32,
    p_cost: u32,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let salt = unsafe { text(salt, salt_len) }?;
        let user_key = unsafe { text(user_key, user_key_len) }?;
        let opt = |v: u32| (v != 0).then_some(v);
        crate::aes::derive_key(salt, user_key, opt(m_cost_kib), opt(t_cost), opt(p_cost))
    })
}

/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_aes_encrypt(
    key: *const u8,
    key_len: usize,
    data: *const u8,
    data_len: usize,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let key = unsafe { bytes(key, key_len) }.to_vec();
        let data = unsafe { bytes(data, data_len) }.to_vec();
        crate::aes::encrypt(key, data)
    })
}

/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_aes_decrypt(
    key: *const u8,
    key_len: usize,
    data: *const u8,
    data_len: usize,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let key = unsafe { bytes(key, key_len) }.to_vec();
        let data = unsafe { bytes(data, data_len) }.to_vec();
        crate::aes::decrypt(key, data)
    })
}

/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_aes_encrypt_file(
    key: *const u8,
    key_len: usize,
    in_path: *const u8,
    in_path_len: usize,
    out_path: *const u8,
    out_path_len: usize,
    prefix: *const u8,
    prefix_len: usize,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let key = unsafe { bytes(key, key_len) }.to_vec();
        let in_path = unsafe { text(in_path, in_path_len) }?;
        let out_path = unsafe { text(out_path, out_path_len) }?;
        let prefix = unsafe { bytes(prefix, prefix_len) };
        crate::aes::encrypt_file(key, in_path, out_path, prefix)?;
        Ok(Vec::new())
    })
}

/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_aes_decrypt_file(
    key: *const u8,
    key_len: usize,
    in_path: *const u8,
    in_path_len: usize,
    out_path: *const u8,
    out_path_len: usize,
    skip_prefix: u64,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let key = unsafe { bytes(key, key_len) }.to_vec();
        let in_path = unsafe { text(in_path, in_path_len) }?;
        let out_path = unsafe { text(out_path, out_path_len) }?;
        crate::aes::decrypt_file(key, in_path, out_path, skip_prefix)?;
        Ok(Vec::new())
    })
}

/// 载荷是 PHC 字符串的 UTF-8。
///
/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_argon2_hash(
    password: *const u8,
    password_len: usize,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let password = unsafe { text(password, password_len) }?;
        Ok(crate::password::hash(password)?.into_bytes())
    })
}

/// 载荷是一个字节：1 匹配，0 不匹配。
///
/// # Safety
/// 指针 / 长度约定见模块文档；`out` 必须可写。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn fastcrypto_argon2_verify(
    hash: *const u8,
    hash_len: usize,
    password: *const u8,
    password_len: usize,
    out: *mut FfiBuf,
) -> i32 {
    run(out, || {
        let hash = unsafe { text(hash, hash_len) }?;
        let password = unsafe { text(password, password_len) }?;
        Ok(vec![u8::from(crate::password::verify(hash, password)?)])
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    unsafe fn call(f: impl FnOnce(*mut FfiBuf) -> i32) -> (i32, Vec<u8>) {
        let mut out = FfiBuf {
            ptr: std::ptr::null_mut(),
            len: 0,
            cap: 0,
        };
        let code = f(&mut out);
        let payload = unsafe { bytes(out.ptr, out.len) }.to_vec();
        unsafe { fastcrypto_buf_free(out.ptr, out.len, out.cap) };
        (code, payload)
    }

    #[test]
    fn round_trip_over_the_c_abi() {
        let (code, key) = unsafe {
            call(|out| {
                fastcrypto_aes_derive_key(b"saltsalt".as_ptr(), 8, b"pw".as_ptr(), 2, 8, 1, 1, out)
            })
        };
        assert_eq!(code, 0, "{}", String::from_utf8_lossy(&key));
        assert_eq!(key.len(), 32);
        let plain = b"hello";
        let (code, cipher) = unsafe {
            call(|out| {
                fastcrypto_aes_encrypt(key.as_ptr(), key.len(), plain.as_ptr(), plain.len(), out)
            })
        };
        assert_eq!(code, 0);
        let (code, back) = unsafe {
            call(|out| {
                fastcrypto_aes_decrypt(key.as_ptr(), key.len(), cipher.as_ptr(), cipher.len(), out)
            })
        };
        assert_eq!((code, back.as_slice()), (0, &plain[..]));
    }

    #[test]
    fn errors_come_back_as_utf8_with_code_1() {
        let (code, msg) = unsafe {
            call(|out| fastcrypto_aes_decrypt(b"short".as_ptr(), 5, b"x".as_ptr(), 1, out))
        };
        assert_eq!(code, 1);
        assert!(!String::from_utf8(msg).unwrap().is_empty());
    }

    #[test]
    fn invalid_utf8_input_is_an_error_not_a_crash() {
        let bad = [0xffu8, 0xfe];
        let (code, _) = unsafe { call(|out| fastcrypto_argon2_hash(bad.as_ptr(), bad.len(), out)) };
        assert_eq!(code, 1);
    }
}
