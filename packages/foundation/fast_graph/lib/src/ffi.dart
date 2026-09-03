// C ABI 声明，与 rust/src/ffi.rs 一一对应。符号经 native assets 的 code asset 解析
// （hook 里的 assetName 就是本文件），不用 dlopen、不用 init。
import 'dart:ffi';

/// `FfiLayoutParams` 的镜像。
final class FfiLayoutParams extends Struct {
  @Uint32()
  external int iterations;
  @Float()
  external double theta;
  @Float()
  external double repulsion;
  @Float()
  external double springLength;
  @Float()
  external double springStrength;
  @Float()
  external double gravity;
  @Float()
  external double collideRadius;
  @Float()
  external double velocityDecay;
  @Uint32()
  external int emitEvery;
  @Uint32()
  external int frameDelayMs;
  @Float()
  external double initialAlpha;
  @Float()
  external double minStep;
  @Uint32()
  external int pinnedCount;
  @Uint8()
  external int normalizeScale;
}

final class LayoutHandle extends Opaque {}

/// `cb(kind, ptr, len)`：kind 0 帧 / 1 完成 / 2 错误；载荷读完必须 [fastgraphBufFree]。
typedef FrameCallbackNative = Void Function(Int32, Pointer<Uint8>, Size);

@Native<Void Function(Pointer<Uint8>, Size)>(symbol: 'fastgraph_buf_free')
external void fastgraphBufFree(Pointer<Uint8> ptr, int len);

@Native<
  Pointer<LayoutHandle> Function(
    Uint32,
    Pointer<Int32>,
    Size,
    Pointer<Float>,
    Size,
    Pointer<FfiLayoutParams>,
    Pointer<NativeFunction<FrameCallbackNative>>,
  )
>(symbol: 'fastgraph_layout_start')
external Pointer<LayoutHandle> fastgraphLayoutStart(
  int nodeCount,
  Pointer<Int32> edges,
  int edgesLen,
  Pointer<Float> initial,
  int initialLen,
  Pointer<FfiLayoutParams> params,
  Pointer<NativeFunction<FrameCallbackNative>> cb,
);

@Native<Void Function(Pointer<LayoutHandle>)>(symbol: 'fastgraph_layout_cancel')
external void fastgraphLayoutCancel(Pointer<LayoutHandle> handle);

@Native<Void Function(Pointer<LayoutHandle>)>(symbol: 'fastgraph_layout_free')
external void fastgraphLayoutFree(Pointer<LayoutHandle> handle);
