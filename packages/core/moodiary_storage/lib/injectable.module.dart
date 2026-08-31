// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_storage/moodiary_storage.dart' as _i877;
import 'package:moodiary_storage/src/kv/mmkv.dart' as _i1046;
import 'package:moodiary_storage/src/kv/secure.dart' as _i345;

class MoodiaryStoragePackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) async {
    await gh.singletonAsync<_i877.ISecureKVStorage>(
      () => _i345.FlutterSecureStorageKVStorage.create(),
      preResolve: true,
    );
    await gh.singletonAsync<_i877.IKVStorage>(
      () => _i1046.MmkvKVStorage.create(gh<_i877.ISecureKVStorage>()),
      preResolve: true,
    );
  }
}
