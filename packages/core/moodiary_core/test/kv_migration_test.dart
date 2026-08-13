import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 内存 KV，只为把 [MoodiaryKVs] 的读写接上。
final class _MemoryKVStorage extends IKVStorage {
  final Map<String, Object> data = {};

  @override
  Future<void> init() async {}

  @override
  T? get<T extends Object>(String key) => data[key] as T?;

  @override
  void set<T extends Object>(String key, T value) {
    data[key] = value;
    super.set(key, value);
  }

  @override
  void remove(String key) {
    data.remove(key);
    super.remove(key);
  }

  @override
  void clear() => data.clear();
}

/// 旧后端的替身：只读，且能模拟「这一格类型对不上」时抛异常的行为。
final class _MemorySource implements IKVSource {
  final Map<String, Object> data = {};
  final Set<String> throwingKeys = {};

  @override
  T? get<T extends Object>(String key) {
    if (throwingKeys.contains(key)) throw TypeError();
    return data[key] as T?;
  }
}

void main() {
  group('MoodiaryKVs.copyFrom', () {
    late _MemorySource source;
    late _MemoryKVStorage target;

    setUp(() {
      source = _MemorySource();
      target = _MemoryKVStorage();
    });

    test('五种值类型都能原样搬过去', () {
      source.data[MoodiaryKVs.appVersion.name] = '2.7.3+92';
      source.data[MoodiaryKVs.autoSync.name] = true;
      source.data[MoodiaryKVs.syncPollInterval.name] = 120;
      source.data[MoodiaryKVs.searchHistory.name] = <String>['a', 'b'];

      for (final kv in MoodiaryKVs.values) {
        kv.copyFrom(source, into: target);
      }

      expect(target.get<String>(MoodiaryKVs.appVersion.name), '2.7.3+92');
      expect(target.get<bool>(MoodiaryKVs.autoSync.name), true);
      expect(target.get<int>(MoodiaryKVs.syncPollInterval.name), 120);
      expect(target.get<List<String>>(MoodiaryKVs.searchHistory.name), [
        'a',
        'b',
      ]);
    });

    test('源里没有的键不写进去——别把 defaultValue 固化成显式值', () {
      MoodiaryKVs.autoSync.copyFrom(source, into: target);
      expect(target.data.containsKey(MoodiaryKVs.autoSync.name), isFalse);
    });

    test('单个键读崩不影响其余键——迁移是逐键 try/catch 的前提', () {
      source.data[MoodiaryKVs.appVersion.name] = '2.7.3+92';
      source.throwingKeys.add(MoodiaryKVs.autoSync.name);

      var skipped = 0;
      for (final kv in MoodiaryKVs.values) {
        try {
          kv.copyFrom(source, into: target);
        } catch (_) {
          skipped++;
        }
      }

      expect(skipped, 1);
      expect(target.get<String>(MoodiaryKVs.appVersion.name), '2.7.3+92');
    });
  });

  /// MMKV / SharedPreferences 两侧的类型分派都是 `switch (T)` 加一个抛异常的
  /// default 分支，加一个 `MoodiaryKVs<Duration>` 之类的键不会有编译错误，
  /// 只会在运行时炸。这条闸门把它挪到编译-测试期。
  test('每个 KV 的值类型都在后端支持的五种之内', () {
    const supported = {'int', 'bool', 'double', 'String', 'List<String>'};
    for (final kv in MoodiaryKVs.values) {
      // defaultValue 为 null 的键从 runtimeType 取不到 T，退而用 toString 里的
      // 泛型实参（`MoodiaryKVs<String>.appVersion`）。
      final generic = RegExp(r'<(.+)>').firstMatch(kv.runtimeType.toString());
      expect(
        supported,
        contains(generic?.group(1)),
        reason: '${kv.name} 的值类型 ${generic?.group(1)} 没有后端实现',
      );
    }
  });
}
