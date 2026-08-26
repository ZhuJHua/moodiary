import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_page.g.dart';

/// 底图需要的两样东西一起等：天地图的 tk 在 SecureKV 里，读它是一次异步的
/// 钥匙串调用。分开 watch 会让底图先按「无 tk」建成 OSM 单层、再重建成天地图双层。
@riverpod
Future<({List<Diary> diaries, String tiandituKey})> mapData(Ref ref) async {
  final withPosition = await ref
      .watch(diaryRepositoryProvider)
      .getDiariesWithPosition();
  final key = await ref.watch(
    secretKvProvider(MoodiarySecureKVs.tiandituKey).future,
  );
  return (
    // 查询层只保证非空；成对经纬度（>=2）这半个校验留在这。
    diaries: withPosition.where((d) => d.position.length >= 2).toList(),
    tiandituKey: key ?? '',
  );
}

class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  // 天地图 WMTS：vec_w 矢量底图 + cva_w 中文注记；需在「实验室」配置 tk。
  static const _tiandituVec =
      'https://t{s}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={tk}';
  static const _tiandituCva =
      'https://t{s}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={tk}';
  static const _tiandituSubdomains = ['0', '1', '2', '3', '4', '5', '6', '7'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mapDataProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diary.mapTitle)),
      body: async.buildLoading(
        data: (data) {
          final (:diaries, :tiandituKey) = data;
          final initialCenter = diaries.isNotEmpty
              ? _parseLatLng(diaries.first.position)
              : const LatLng(39.9, 116.4);
          return FlutterMap(
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: diaries.isNotEmpty ? 12 : 4,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              ..._tileLayers(tiandituKey),
              MarkerLayer(
                markers: [
                  for (final d in diaries)
                    Marker(
                      point: _parseLatLng(d.position),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _openDiary(context, d),
                        child: Icon(
                          LucideIcons.mapPin,
                          color: context.theme.colors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tileLayers(String tiandituKey) {
    if (tiandituKey.isEmpty) {
      return [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'net.moodiary',
        ),
      ];
    }
    return [
      TileLayer(
        urlTemplate: _tiandituVec,
        subdomains: _tiandituSubdomains,
        additionalOptions: {'tk': tiandituKey},
        userAgentPackageName: 'net.moodiary',
      ),
      TileLayer(
        urlTemplate: _tiandituCva,
        subdomains: _tiandituSubdomains,
        additionalOptions: {'tk': tiandituKey},
        userAgentPackageName: 'net.moodiary',
      ),
    ];
  }

  void _openDiary(BuildContext context, Diary diary) {
    final route = DiaryRoute(
      type: DiaryType.fromValue(diary.type).routeQuery,
      diaryId: diary.id,
    );
    // 足迹地图归属 Setting 分支，打开日记需切到 Diary 分支后全屏 push。
    route.push(context);
  }

  LatLng _parseLatLng(List<String> position) {
    final lat = double.tryParse(position[0]) ?? 0;
    final lng = double.tryParse(position[1]) ?? 0;
    return LatLng(lat, lng);
  }
}
