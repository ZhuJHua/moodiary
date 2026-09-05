import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_page.g.dart';

/// 底图需要的两样东西一起等：天地图的 tk 在 SecureKV 里，读它是一次异步的
/// 钥匙串调用。分开 watch 会让底图先按「无 tk」建成 OSM 单层、再重建成天地图双层。
typedef PlacePin = ({Place place, List<Diary> diaries});

/// 日记引用常用地点，足迹 = 有日记的地点各打一个点，同一地点的日记挂在一起。
@riverpod
Future<({List<PlacePin> pins, String tiandituKey})> mapData(Ref ref) async {
  final diaries = await getIt<DiaryRepository>().getDiariesWithPlace();
  final places = await getIt<PlaceRepository>().getAllPlaces();
  final key = await ref.watch(
    secretKvProvider(MoodiarySecureKVs.tiandituKey).future,
  );
  final byPlace = <String, List<Diary>>{};
  for (final d in diaries) {
    (byPlace[d.placeId!] ??= []).add(d);
  }
  return (
    pins: [
      for (final p in places)
        if (byPlace[p.id] case final ds?) (place: p, diaries: ds),
    ],
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
          final (:pins, :tiandituKey) = data;
          final initialCenter = pins.isNotEmpty
              ? _latLng(pins.first.place)
              : const LatLng(39.9, 116.4);
          return FlutterMap(
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: pins.isNotEmpty ? 12 : 4,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              ..._tileLayers(tiandituKey),
              MarkerLayer(
                markers: [
                  for (final pin in pins)
                    Marker(
                      point: _latLng(pin.place),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _openPin(context, pin),
                        child: _PinIcon(count: pin.diaries.length),
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

  /// 一篇直接开；多篇先列出来选。
  Future<void> _openPin(BuildContext context, PlacePin pin) async {
    if (pin.diaries.length == 1) return _openDiary(context, pin.diaries.first);
    final picked = await MSheet.show<Diary>(
      context,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const .fromLTRB(8, 0, 8, 16),
        children: [
          for (final (i, d) in pin.diaries.indexed)
            SettingListTile(
              isFirst: i == 0,
              isLast: i == pin.diaries.length - 1,
              title: d.title.trim().isEmpty
                  ? context.l10n.common.untitled
                  : d.title,
              subtitle: TimeFormat.weekdayTimeHms(d.time),
              onTap: () => Navigator.of(context).pop(d),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) _openDiary(context, picked);
  }

  void _openDiary(BuildContext context, Diary diary) {
    final route = DiaryRoute(
      type: DiaryType.fromValue(diary.type).routeQuery,
      diaryId: diary.id,
    );
    // 足迹地图归属 Setting 分支，打开日记需切到 Diary 分支后全屏 push。
    route.push(context);
  }

  LatLng _latLng(Place place) => LatLng(place.latitude, place.longitude);
}

/// 图钉 + 篇数角标（一篇不带角标）。
class _PinIcon extends StatelessWidget {
  final int count;

  const _PinIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Stack(
      clipBehavior: .none,
      alignment: .center,
      children: [
        Icon(LucideIcons.mapPin, color: colors.primary, size: 32),
        if (count > 1)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const .symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: .circular(9),
              ),
              child: Text(
                '$count',
                style: context.theme.typography.labelSmall.onPrimary,
              ),
            ),
          ),
      ],
    );
  }
}
