import 'dart:io';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'lru.dart';

/// 图片宽高 / 宽高比的统一读取入口。从文件头元数据解析宽高（不解码整图），
/// 开销极低，故只挂内存 [LRUCache] 去重、不持久化。
class ImageSizeManager {
  ImageSizeManager._();

  static final ImageSizeManager _instance = ._();

  factory ImageSizeManager() => _instance;

  final _aspectRatioCache = LRUCache<String, double>(maxSize: 1000);

  /// 宽高比（已按 EXIF 方向校正）。[imagePath] 兼作缓存 key；文件缺失/不支持时抛出。
  double getAspectRatio(String imagePath) {
    final cached = _aspectRatioCache.get(imagePath);
    if (cached != null) return cached;

    final (width, height) = getSize(imagePath);
    final aspectRatio = width / height;
    _aspectRatioCache.put(imagePath, aspectRatio);
    return aspectRatio;
  }

  /// 像素宽高（已按 EXIF 方向校正），返回 `(width, height)`。
  (int, int) getSize(String imagePath) {
    final size = ImageSizeGetter.getSizeResult(FileInput(File(imagePath))).size;
    // needRotate=EXIF 方向 90/270 度，宽高需互换。
    return size.needRotate
        ? (size.height, size.width)
        : (size.width, size.height);
  }

  /// [getAspectRatio] 的异步版：文件走异步 IO，不在主 isolate 同步读盘。
  Future<double> getAspectRatioAsync(String imagePath) async {
    final cached = _aspectRatioCache.get(imagePath);
    if (cached != null) return cached;

    final (width, height) = await getSizeAsync(imagePath);
    final aspectRatio = width / height;
    _aspectRatioCache.put(imagePath, aspectRatio);
    return aspectRatio;
  }

  /// [getSize] 的异步版。
  Future<(int, int)> getSizeAsync(String imagePath) async {
    final input = _AsyncFileInput(File(imagePath));
    try {
      final size = (await ImageSizeGetter.getSizeResultAsync(input)).size;
      return size.needRotate
          ? (size.height, size.width)
          : (size.width, size.height);
    } finally {
      await input.close();
    }
  }

  void clear() => _aspectRatioCache.clear();
}

/// [AsyncImageInput] 的文件实现。包自带 [FileInput] 是同步读（`AsyncImageInput.input`
/// 包装后依旧），这里改走 [RandomAccessFile] 异步接口。头部解析会多次 getRange，
/// 句柄惰性打开后复用，调用方用完 [close]。
class _AsyncFileInput extends AsyncImageInput {
  _AsyncFileInput(this._file);

  final File _file;
  Future<RandomAccessFile>? _raf;

  Future<RandomAccessFile> _open() => _raf ??= _file.open();

  Future<void> close() async {
    final raf = _raf;
    _raf = null;
    if (raf != null) await (await raf).close();
  }

  @override
  Future<bool> supportRangeLoad() async => true;

  @override
  Future<HaveResourceImageInput> delegateInput() async =>
      HaveResourceImageInput(innerInput: FileInput(_file));

  @override
  Future<int> get length => _file.length();

  @override
  Future<List<int>> getRange(int start, int end) async {
    final raf = await _open();
    await raf.setPosition(start);
    return raf.read(end - start);
  }

  @override
  Future<bool> exists() => _file.exists();
}
