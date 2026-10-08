import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../map/map_tile_source.dart';
import '../map/map_tiles.dart';

const List<String> kPlaceIcons = [
  'house',
  'building-2',
  'school',
  'coffee',
  'dumbbell',
  'trees',
  'hospital',
  'plane',
];

IconData placeIconOf(String? name) => switch (name) {
  'house' => LucideIcons.house,
  'building-2' => LucideIcons.building2,
  'school' => LucideIcons.school,
  'coffee' => LucideIcons.coffee,
  'dumbbell' => LucideIcons.dumbbell,
  'trees' => LucideIcons.trees,
  'hospital' => LucideIcons.hospital,
  'plane' => LucideIcons.plane,
  _ => LucideIcons.mapPin,
};

Color placeIconColor(BuildContext context, String? icon) => switch (icon) {
  'house' => kCategoryPalette[7],
  'building-2' => kCategoryPalette[5],
  'school' => kCategoryPalette[2],
  'coffee' => kCategoryPalette[9],
  'dumbbell' => kCategoryPalette[8],
  'trees' => kCategoryPalette[6],
  'hospital' => kCategoryPalette[0],
  'plane' => kCategoryPalette[4],
  _ => context.theme.colors.outline,
};

class PlaceBadge extends StatelessWidget {
  final Place place;
  final double size;

  const PlaceBadge({super.key, required this.place, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final color = placeIconColor(context, place.icon);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: .circular(size * 0.3),
      ),
      child: Icon(
        placeIconOf(place.icon),
        size: size / 2,
        color: onCategoryColor(color),
      ),
    );
  }
}

String formatDistance(BuildContext context, double meters) {
  if (meters < 1000) {
    return context.l10n.diary.placeDistanceMeters(meters: meters.round());
  }
  return context.l10n.diary.placeDistanceKilometers(
    km: (meters / 1000).toStringAsFixed(1),
  );
}

Future<Place?> showPlaceEditor(
  BuildContext context, {
  Place? existing,
  double? latitude,
  double? longitude,
  String? initialName,
}) async {
  final draft = _PlaceDraft(
    name: existing?.name ?? initialName ?? '',
    icon: existing?.icon ?? kPlaceIcons.first,
    latitude: existing?.latitude ?? latitude,
    longitude: existing?.longitude ?? longitude,
  );
  final confirmed = await MSheet.show<bool>(
    context,
    builder: (_) => _PlaceEditorSheet(draft: draft, existing: existing),
  );
  if (confirmed != true || !context.mounted) return null;

  final lat = draft.latitude;
  final lon = draft.longitude;
  if (lat == null || lon == null) return null;
  final place = existing == null
      ? Place.create(
          name: draft.name.trim(),
          latitude: lat,
          longitude: lon,
          icon: draft.icon,
        )
      : existing.copyWith(
          name: draft.name.trim(),
          latitude: lat,
          longitude: lon,
          icon: draft.icon,
          lastModified: DateTime.timestamp(),
        );
  try {
    await getIt<PlaceRepository>().insertAPlace(place);
  } catch (e, s) {
    logger.e('save place failed', error: e, stackTrace: s);
    if (context.mounted) toast.error(message: l10n.diary.placeSaveFailed);
    return null;
  }
  return place;
}

const double _kEditorZoom = 16;

class _PlaceDraft {
  String name;
  String icon;
  double? latitude;
  double? longitude;

  bool relocate = false;

  _PlaceDraft({
    required this.name,
    required this.icon,
    required this.latitude,
    required this.longitude,
  });
}

class _PlaceEditorSheet extends ConsumerStatefulWidget {
  final _PlaceDraft draft;
  final Place? existing;

  const _PlaceEditorSheet({required this.draft, required this.existing});

  @override
  ConsumerState<_PlaceEditorSheet> createState() => _PlaceEditorSheetState();
}

class _PlaceEditorSheetState extends ConsumerState<_PlaceEditorSheet> {
  late final _controller = TextEditingController(text: widget.draft.name);
  final _map = MapController();

  bool _edited = false;
  bool _locating = false;
  bool _mapReady = false;

  _PlaceDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    if (_draft.latitude == null) {
      _locating = true;
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<bool> _locate() {
    setState(() => _locating = true);
    return _fetchLocation();
  }

  Future<bool> _fetchLocation() async {
    final result = await LocationService.current(precise: true);
    if (!mounted) return false;
    final failure = result.failure;
    setState(() {
      _locating = false;
      if (failure == null) {
        _draft.latitude = result.latitude;
        _draft.longitude = result.longitude;
      }
    });
    if (failure != null) {
      toast.error(message: _failureMessage(failure));
      return false;
    }
    _moveMap();
    return true;
  }

  void _moveMap() {
    final lat = _draft.latitude;
    final lon = _draft.longitude;
    if (!_mapReady || lat == null || lon == null) return;
    _map.move(LatLng(lat, lon), math.max(_map.camera.zoom, _kEditorZoom));
  }

  void _onMapReady() {
    _mapReady = true;
    _moveMap();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _draft.latitude = camera.center.latitude;
    _draft.longitude = camera.center.longitude;
  }

  Future<bool> _submit() async {
    if (_draft.name.trim().isEmpty) {
      setState(() => _edited = true);
      return false;
    }
    if (_draft.latitude != null && !_draft.relocate) return true;
    return _locate();
  }

  String _failureMessage(LocationFailure failure) => switch (failure) {
    LocationFailure.permissionDenied => l10n.diary.positionPermissionDenied,
    LocationFailure.permissionDeniedForever =>
      l10n.diary.positionPermissionForever,
    LocationFailure.serviceOff => l10n.diary.positionServiceOff,
    LocationFailure.unavailable => l10n.diary.positionFailed,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final l10n = context.l10n;
    final source = MapTileSource.of(MoodiaryKVs.mapTileSource.get()!);
    final tiandituKey =
        ref.watch(secretKvProvider(MoodiarySecureKVs.tiandituKey)).value ?? '';
    final showMap =
        source != null && (source != .tianditu || tiandituKey.isNotEmpty);
    final others = <Place>[
      for (final p in ref.watch(placeControllerProvider).value ?? const [])
        if (p.id != widget.existing?.id) p,
    ];
    OutlineInputBorder border([BorderSide side = .none]) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: side,
    );

    return MSheetScaffold<bool>(
      title: widget.existing == null
          ? l10n.diary.placeCreateTitle
          : l10n.diary.placeEditTitle,
      actions: [
        MAction(label: l10n.common.cancel, value: false),
        MAction(
          label: l10n.common.ok,
          value: true,
          isPrimary: true,
          busy: _locating,
          onSubmit: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          if (showMap) ...[
            _buildMap(source, tiandituKey, others),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            autofocus: !showMap,
            textInputAction: .done,
            onChanged: (value) => setState(() {
              _edited = true;
              _draft.name = value;
            }),
            style: theme.typography.bodyLarge.onSurface,
            decoration: InputDecoration(
              labelText: l10n.diary.placeNameLabel,
              errorText: _edited && _draft.name.trim().isEmpty
                  ? l10n.diary.placeNameEmpty
                  : null,
              filled: true,
              isDense: true,
              fillColor: colors.surfaceContainerHighest,
              contentPadding: const .symmetric(horizontal: 16, vertical: 13),
              border: border(),
              enabledBorder: border(),
              focusedBorder: border(
                BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.diary.placeIconLabel,
            style: theme.typography.labelMedium.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in kPlaceIcons)
                _IconTile(
                  name: name,
                  selected: _draft.icon == name,
                  onTap: () => setState(() => _draft.icon = name),
                ),
            ],
          ),
          if (!showMap && widget.existing != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.diary.placeRelocate,
                    style: theme.typography.bodyMedium.onSurface,
                  ),
                ),
                Switch(
                  value: _draft.relocate,
                  onChanged: (v) => setState(() => _draft.relocate = v),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(
    MapTileSource source,
    String tiandituKey,
    List<Place> others,
  ) {
    final theme = context.theme;
    final lat = _draft.latitude;
    final lon = _draft.longitude;
    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: .circular(theme.radii.lg),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: lat != null && lon != null
                    ? LatLng(lat, lon)
                    : const LatLng(35, 105),
                initialZoom: lat != null ? _kEditorZoom : 3,
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: theme.colors.surfaceContainerHighest,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                ...mapTileLayers(
                  source,
                  tiandituKey: tiandituKey,
                  retina: MediaQuery.devicePixelRatioOf(context) > 1,
                ),
                CircleLayer(
                  circles: [
                    for (final p in others)
                      CircleMarker(
                        point: LatLng(p.latitude, p.longitude),
                        radius: Place.matchRadius.toDouble(),
                        useRadiusInMeter: true,
                        color: placeIconColor(
                          context,
                          p.icon,
                        ).withValues(alpha: 0.14),
                        borderColor: placeIconColor(
                          context,
                          p.icon,
                        ).withValues(alpha: 0.55),
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final p in others)
                      Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 26,
                        height: 26,
                        child: PlaceBadge(place: p, size: 26),
                      ),
                  ],
                ),
              ],
            ),
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 36,
                    color: placeIconColor(context, _draft.icon),
                    shadows: MGlassSurface.defaultShadows(theme.colors),
                  ),
                ),
              ),
            ),
            if (_locating)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.overlay,
                  child: Column(
                    mainAxisAlignment: .center,
                    children: [
                      const MLoading(),
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.diary.positionLocating,
                        style: theme.typography.labelMedium.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: MapAttribution(source: source),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: MCircleButton(
                tone: .overlay,
                elevated: true,
                size: 36,
                tooltip: context.l10n.diary.placeRelocate,
                icon: const Icon(LucideIcons.locateFixed),
                onPressed: _locating ? null : _locate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _IconTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final color = placeIconColor(context, name);
    return MInkWell(
      onTap: onTap,
      borderRadius: .circular(12),
      child: AnimatedContainer(
        duration: Durations.short4,
        curve: Easing.emphasizedDecelerate,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? color : colors.surfaceContainerHighest,
          borderRadius: .circular(12),
        ),
        child: Icon(
          placeIconOf(name),
          size: 20,
          color: selected ? onCategoryColor(color) : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
