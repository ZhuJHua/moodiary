// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 底图需要的两样东西一起等：天地图的 tk 在 SecureKV 里，读它是一次异步的
/// 钥匙串调用。分开 watch 会让底图先按「无 tk」建成 OSM 单层、再重建成天地图双层。

@ProviderFor(mapData)
final mapDataProvider = MapDataProvider._();

/// 底图需要的两样东西一起等：天地图的 tk 在 SecureKV 里，读它是一次异步的
/// 钥匙串调用。分开 watch 会让底图先按「无 tk」建成 OSM 单层、再重建成天地图双层。

final class MapDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<({List<Diary> diaries, String tiandituKey})>,
          ({List<Diary> diaries, String tiandituKey}),
          FutureOr<({List<Diary> diaries, String tiandituKey})>
        >
    with
        $FutureModifier<({List<Diary> diaries, String tiandituKey})>,
        $FutureProvider<({List<Diary> diaries, String tiandituKey})> {
  /// 底图需要的两样东西一起等：天地图的 tk 在 SecureKV 里，读它是一次异步的
  /// 钥匙串调用。分开 watch 会让底图先按「无 tk」建成 OSM 单层、再重建成天地图双层。
  MapDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapDataHash();

  @$internal
  @override
  $FutureProviderElement<({List<Diary> diaries, String tiandituKey})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({List<Diary> diaries, String tiandituKey})> create(Ref ref) {
    return mapData(ref);
  }
}

String _$mapDataHash() => r'c28439251c97c95a6aeddf617efd2e220ce7b5be';
