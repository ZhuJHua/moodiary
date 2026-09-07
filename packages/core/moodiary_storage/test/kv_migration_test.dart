import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'package:moodiary_storage/testing.dart';

void main() {
  group('MoodiaryKVs.copyFrom', () {
    late MemoryKVSource source;
    late MemoryKVStorage target;

    setUp(() {
      source = MemoryKVSource();
      target = MemoryKVStorage();
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

  test('每个 KV 的值类型都在后端支持的五种之内', () {
    const supported = {'int', 'bool', 'double', 'String', 'List<String>'};
    for (final kv in MoodiaryKVs.values) {
      final generic = RegExp(r'<(.+)>').firstMatch(kv.runtimeType.toString());
      expect(
        supported,
        contains(generic?.group(1)),
        reason: '${kv.name} 的值类型 ${generic?.group(1)} 没有后端实现',
      );
    }
  });
}
