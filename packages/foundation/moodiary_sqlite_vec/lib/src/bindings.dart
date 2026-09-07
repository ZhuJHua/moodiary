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

Pointer<Void> vecInitAddress() =>
    Native.addressOf<NativeFunction<_VecInitNative>>(_sqlite3VecInit).cast();
