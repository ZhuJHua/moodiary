// C ABI 声明，与 rust/src/ffi.rs 一一对应。符号经 native assets 的 code asset 解析
// （hook 里的 assetName 就是本文件），不用 dlopen、不用 init。
import 'dart:ffi';

/// Rust 堆上的一段字节，所有权在 Dart 手里，读完必须 [fastcryptoBufFree]。
final class FfiBuf extends Struct {
  external Pointer<Uint8> ptr;
  @Size()
  external int len;
  @Size()
  external int cap;
}

@Native<Void Function(Pointer<Uint8>, Size, Size)>(
  symbol: 'fastcrypto_buf_free',
)
external void fastcryptoBufFree(Pointer<Uint8> ptr, int len, int cap);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Uint32,
    Uint32,
    Uint32,
    Pointer<FfiBuf>,
  )
>(symbol: 'fastcrypto_aes_derive_key')
external int fastcryptoAesDeriveKey(
  Pointer<Uint8> salt,
  int saltLen,
  Pointer<Uint8> userKey,
  int userKeyLen,
  int mCostKib,
  int tCost,
  int pCost,
  Pointer<FfiBuf> out,
);

@Native<
  Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size, Pointer<FfiBuf>)
>(symbol: 'fastcrypto_aes_encrypt')
external int fastcryptoAesEncrypt(
  Pointer<Uint8> key,
  int keyLen,
  Pointer<Uint8> data,
  int dataLen,
  Pointer<FfiBuf> out,
);

@Native<
  Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size, Pointer<FfiBuf>)
>(symbol: 'fastcrypto_aes_decrypt')
external int fastcryptoAesDecrypt(
  Pointer<Uint8> key,
  int keyLen,
  Pointer<Uint8> data,
  int dataLen,
  Pointer<FfiBuf> out,
);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<FfiBuf>,
  )
>(symbol: 'fastcrypto_aes_encrypt_file')
external int fastcryptoAesEncryptFile(
  Pointer<Uint8> key,
  int keyLen,
  Pointer<Uint8> inPath,
  int inPathLen,
  Pointer<Uint8> outPath,
  int outPathLen,
  Pointer<Uint8> prefix,
  int prefixLen,
  Pointer<FfiBuf> out,
);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Uint64,
    Pointer<FfiBuf>,
  )
>(symbol: 'fastcrypto_aes_decrypt_file')
external int fastcryptoAesDecryptFile(
  Pointer<Uint8> key,
  int keyLen,
  Pointer<Uint8> inPath,
  int inPathLen,
  Pointer<Uint8> outPath,
  int outPathLen,
  int skipPrefix,
  Pointer<FfiBuf> out,
);

@Native<Int32 Function(Pointer<Uint8>, Size, Pointer<FfiBuf>)>(
  symbol: 'fastcrypto_argon2_hash',
)
external int fastcryptoArgon2Hash(
  Pointer<Uint8> password,
  int passwordLen,
  Pointer<FfiBuf> out,
);

@Native<
  Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size, Pointer<FfiBuf>)
>(symbol: 'fastcrypto_argon2_verify')
external int fastcryptoArgon2Verify(
  Pointer<Uint8> hash,
  int hashLen,
  Pointer<Uint8> password,
  int passwordLen,
  Pointer<FfiBuf> out,
);
