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

typedef PlacePin = ({Place place, List<Diary> diaries});

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

  // vec_w = 矢量底图，cva_w = 中文注记
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
    DiaryRoute(diaryId: diary.id).push(context);
  }

  LatLng _latLng(Place place) => LatLng(place.latitude, place.longitude);
}

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
