import 'dart:ffi';

typedef _VecInitNative = Int32 Function(
  Pointer<Void>,
  Pointer<Pointer<Char>>,
  Pointer<Void>,
);

@Native<_VecInitNative>(symbol: 'sqlite3_vec_init')
external int _sqlite3VecInit(
  Pointer<Void> db,
  Pointer<Pointer<Char>> pzErrMsg,
  Pointer<Void> pApi,
);

/// `sqlite3_vec_init` 的函数地址，供 `sqlite3_auto_extension` 注册。
Pointer<Void> vecInitAddress() =>
    Native.addressOf<NativeFunction<_VecInitNative>>(_sqlite3VecInit).cast();
