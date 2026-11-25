import 'package:flutter/foundation.dart';

import 'storage.dart';

abstract final class KVStore {
  static IKVStorage? _instance;
  static IKVStorage get instance =>
      _instance ?? (throw StateError('KVStore is not installed'));

  static void install(IKVStorage storage) {
    if (_instance != null) throw StateError('KVStore is already installed');
    _instance = storage;
  }

  @visibleForTesting
  static void installForTesting(IKVStorage storage) => _instance = storage;

  @visibleForTesting
  static void resetForTesting() => _instance = null;
}

abstract final class SecureKVStore {
  static ISecureKVStorage? _instance;
  static ISecureKVStorage get instance =>
      _instance ?? (throw StateError('SecureKVStore is not installed'));

  static void install(ISecureKVStorage storage) {
    if (_instance != null) {
      throw StateError('SecureKVStore is already installed');
    }
    _instance = storage;
  }

  @visibleForTesting
  static void installForTesting(ISecureKVStorage storage) =>
      _instance = storage;

  @visibleForTesting
  static void resetForTesting() => _instance = null;
}
