import 'package:moodiary_core/moodiary_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_controller.g.dart';

@riverpod
class CacheController extends _$CacheController {
  @override
  Future<CacheUsage> build() async {
    final map = await FileUtil.countSize();
    return CacheUsage(
      display: '${map['size']} ${map['unit']}',
      bytes: map['bytes'] as int,
    );
  }

  Future<void> clear() async {
    await FileUtil.clearCache();
    ref.invalidateSelf();
  }
}

class CacheUsage {
  final String display;
  final int bytes;
  const CacheUsage({required this.display, required this.bytes});
}
