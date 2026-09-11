import 'dart:io';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

import 'lru.dart';

class ImageSizeManager {
  ImageSizeManager._();

  static final ImageSizeManager _instance = ._();

  factory ImageSizeManager() => _instance;

  final _sizeCache = LRUCache<String, (int, int)>(maxSize: 1000);

  double getAspectRatio(String imagePath) {
    final (width, height) = getSize(imagePath);
    return width / height;
  }

  (int, int) getSize(String imagePath) {
    final cached = _sizeCache.get(imagePath);
    if (cached != null) return cached;

    final size = ImageSizeGetter.getSizeResult(FileInput(File(imagePath))).size;
    final result = size.needRotate
        ? (size.height, size.width)
        : (size.width, size.height);
    _sizeCache.put(imagePath, result);
    return result;
  }

  Future<double> getAspectRatioAsync(String imagePath) async {
    final (width, height) = await getSizeAsync(imagePath);
    return width / height;
  }

  Future<(int, int)> getSizeAsync(String imagePath) async {
    final cached = _sizeCache.get(imagePath);
    if (cached != null) return cached;

    final input = _AsyncFileInput(File(imagePath));
    try {
      final size = (await ImageSizeGetter.getSizeResultAsync(input)).size;
      final result = size.needRotate
          ? (size.height, size.width)
          : (size.width, size.height);
      _sizeCache.put(imagePath, result);
      return result;
    } finally {
      await input.close();
    }
  }

  void clear() => _sizeCache.clear();
}

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
