import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'kv/app_lock_pin.dart';
import 'kv_keys.dart';
import 'storage.dart';
import 'storage_holder.dart';

part 'storage_providers.g.dart';

@Riverpod(keepAlive: true)
IKVStorage kvStorage(Ref ref) => KVStore.instance;

@Riverpod(keepAlive: true)
ISecureKVStorage secureKvStorage(Ref ref) => SecureKVStore.instance;

T _listen<T>(Ref ref, ValueListenable<T> source) {
  void changed() => ref.invalidateSelf();
  source.addListener(changed);
  ref.onDispose(() => source.removeListener(changed));
  return source.value;
}

@riverpod
T kvValue<T extends Object>(Ref ref, MoodiaryKVs<T> key) {
  final fallback = key.defaultValue;
  if (fallback == null) throw StateError('${key.name} requires a fallback');
  return _watchKey(ref, key, fallback);
}

@riverpod
T kvValueOr<T extends Object>(Ref ref, MoodiaryKVs<T> key, T fallback) =>
    _watchKey(ref, key, key.defaultValue ?? fallback);

T _watchKey<T extends Object>(Ref ref, MoodiaryKVs<T> key, T fallback) {
  final storage = ref.watch(kvStorageProvider);
  final notifier = storage.getNotifier<T>(key.name, fallback);
  _listen(ref, notifier);
  return storage.get<T>(key.name) ?? fallback;
}

@Riverpod(keepAlive: true)
bool appLockEnabled(Ref ref) => _listen(ref, AppLockPin.enabled);
