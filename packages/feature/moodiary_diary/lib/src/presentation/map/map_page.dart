import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:collection/collection.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../place/place_editor.dart';
import '../widget/diary_entry_tile.dart';
import 'map_tile_source.dart';
import 'map_tiles.dart';

part 'map_page.g.dart';

typedef Footprint = ({Place place, PlaceFootprint stat});

@riverpod
Future<List<Footprint>> footprints(Ref ref) async {
  final (places, stats) = await (
    ref.watch(placeControllerProvider.future),
    ref.watch(placeFootprintsProvider.future),
  ).wait;
  return [
    for (final p in places)
      if (stats[p.id] case final s?) (place: p, stat: s),
  ];
}

typedef _Camera = ({LatLng center, double zoom});

const double _kCardHeight = 280;
const double _kCardInset = 16;
const double _kFitMaxZoom = 13;
const double _kFocusZoom = 14;

LatLng _latLng(Place p) => LatLng(p.latitude, p.longitude);

String _range(DateTime first, DateTime last) {
  final a = TimeFormat.yearMonth(first);
  final b = TimeFormat.yearMonth(last);
  return a == b ? a : '$a – $b';
}

CameraFit _fitOf(List<Footprint> fps, EdgeInsets padding) =>
    CameraFit.coordinates(
      coordinates: [for (final fp in fps) _latLng(fp.place)],
      padding: padding,
      maxZoom: _kFitMaxZoom,
    );

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with TickerProviderStateMixin {
  late final _expand = AnimationController(
    vsync: this,
    duration: Durations.medium3,
    reverseDuration: Durations.medium2,
  )..addStatusListener(_onExpandStatus);
  late final _progress = CurvedAnimation(
    parent: _expand,
    curve: Easing.emphasizedDecelerate,
    reverseCurve: Easing.emphasizedDecelerate.flipped,
  );
  late final _camera = AnimationController(vsync: this)
    ..addListener(_tweenCamera);
  final _source = MoodiaryKVs.mapTileSource.getNotifier();

  MapController _map = MapController();
  CameraFit? _initialFit;
  bool _mapReady = false;
  bool _errorShown = false;
  bool _cardMoved = false;
  String? _selectedPlaceId;
  ({_Camera from, _Camera to})? _cameraTween;

  static const _programmaticSources = {
    MapEventSource.mapController,
    MapEventSource.fitCamera,
    MapEventSource.nonRotatedSizeChange,
    MapEventSource.interactiveFlagsChanged,
    MapEventSource.custom,
  };

  List<Footprint> get _fps => ref.read(footprintsProvider).value ?? const [];

  Size get _screen => MediaQuery.sizeOf(context);

  Size get _cardSize => Size(_screen.width - _kCardInset * 2, _kCardHeight);

  _Camera get _current => (center: _map.camera.center, zoom: _map.camera.zoom);

  bool get _mapAvailable {
    final source = MapTileSource.of(_source.value);
    final key =
        ref.read(secretKvProvider(MoodiarySecureKVs.tiandituKey)).value ?? '';
    return source != null && (source != .tianditu || key.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _source.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    _progress.dispose();
    _expand.dispose();
    _camera.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    setState(() => _errorShown = false);
    _collapseIfUnavailable();
  }

  void _onMapReady() => _mapReady = true;

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (_errorShown) return;
    _errorShown = true;
    toast.error(message: l10n.diary.mapLoadFailed);
  }

  void _onMapEvent(MapEvent event) {
    if (!_expand.isDismissed || _cardMoved || event is! MapEventMove) return;
    if (_programmaticSources.contains(event.source)) return;
    setState(() => _cardMoved = true);
  }

  void _onExpandStatus(AnimationStatus status) {
    if (status.isDismissed) _cardMoved = false;
    setState(() {});
  }

  void _tweenCamera() {
    final tween = _cameraTween;
    if (tween == null) return;
    final t = Easing.emphasizedDecelerate.transform(_camera.value);
    _map.move(
      LatLng(
        lerpDouble(tween.from.center.latitude, tween.to.center.latitude, t)!,
        lerpDouble(tween.from.center.longitude, tween.to.center.longitude, t)!,
      ),
      lerpDouble(tween.from.zoom, tween.to.zoom, t)!,
    );
  }

  void _animateCamera(_Camera to, Duration duration) {
    if (!_mapReady) return;
    _cameraTween = (from: _current, to: to);
    _camera
      ..duration = duration
      ..forward(from: 0);
  }

  _Camera _fitCamera(EdgeInsets padding, Size size) {
    final camera = _fitOf(
      _fps,
      padding,
    ).fit(_map.camera.withNonRotatedSize(size));
    return (center: camera.center, zoom: camera.zoom);
  }

  _Camera _cardOverview() => _fitCamera(const .all(36), _cardSize);

  _Camera _fullOverview() {
    final insets = MediaQuery.paddingOf(context);
    return _fitCamera(
      .fromLTRB(48, insets.top + 72, 48, insets.bottom + 56),
      _screen,
    );
  }

  void _expandMap() {
    if (!_mapReady || !_expand.isDismissed) return;
    _animateCamera(_fullOverview(), Durations.medium3);
    _expand.forward();
  }

  void _collapse() {
    if (_expand.isDismissed || _expand.status == .reverse) return;
    if (!_mapReady || _fps.isEmpty) {
      _expand.value = 0;
      return;
    }
    _animateCamera(_cardOverview(), Durations.medium2);
    _expand.reverse();
  }

  void _collapseIfUnavailable() {
    if (!_mapAvailable) _collapse();
  }

  void _resetCard() {
    _animateCamera(_cardOverview(), Durations.medium3);
    setState(() => _cardMoved = false);
  }

  void _resetMap() {
    final old = _map;
    _map = MapController();
    _mapReady = false;
    _initialFit = null;
    _cameraTween = null;
    _camera.stop();
    _expand.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _openPlace(Footprint fp) async {
    setState(() => _selectedPlaceId = fp.place.id);
    await MSheet.show<void>(
      context,
      builder: (_) => _PlaceSheet(placeId: fp.place.id),
    );
    if (mounted) setState(() => _selectedPlaceId = null);
  }

  void _onPlaceTap(Footprint fp) {
    if (_mapAvailable && !_expand.isAnimating) {
      _animateCamera((
        center: _latLng(fp.place),
        zoom: math.max(_map.camera.zoom, _kFocusZoom),
      ), Durations.medium3);
      if (_expand.isDismissed) setState(() => _cardMoved = true);
    }
    _openPlace(fp);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(footprintsProvider, (prev, next) {
      final hadPlaces = prev?.value?.isNotEmpty ?? false;
      if (hadPlaces && (next.value?.isEmpty ?? false)) _resetMap();
    });
    ref.listen(secretKvProvider(MoodiarySecureKVs.tiandituKey), (_, _) {
      _errorShown = false;
      _collapseIfUnavailable();
    });
    final async = ref.watch(footprintsProvider);
    final keyAsync = ref.watch(secretKvProvider(MoodiarySecureKVs.tiandituKey));
    return PopScope(
      canPop: _expand.isDismissed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collapse();
      },
      child: Scaffold(
        appBar: async.hasValue ? null : _appBar(context),
        body: async.buildLoading(
          data: (fps) => _buildBody(context, fps, keyAsync),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) =>
      AppBar(title: Text(context.l10n.diary.mapTitle));

  Widget _buildBody(
    BuildContext context,
    List<Footprint> fps,
    AsyncValue<String?> keyAsync,
  ) {
    final header = _appBar(context);
    if (fps.isEmpty) {
      return Column(
        children: [
          header,
          const Expanded(child: _Empty()),
        ],
      );
    }

    final l10n = context.l10n.diary;
    final source = MapTileSource.of(_source.value);
    final tiandituKey = keyAsync.value ?? '';
    final mapAvailable =
        source != null && (source != .tianditu || tiandituKey.isNotEmpty);
    final sorted = [...fps]
      ..sort((a, b) => b.stat.count.compareTo(a.stat.count));

    final list = ListView.builder(
      padding: .fromLTRB(_kCardInset, 12, _kCardInset, context.safeBottom + 16),
      itemCount: sorted.length,
      itemBuilder: (context, i) =>
          _PlaceTile(fp: sorted[i], onTap: () => _onPlaceTap(sorted[i])),
    );

    final cover = switch (source) {
      null => _MapCover(
        message: l10n.mapChooseSource,
        actions: [
          for (final s in MapTileSource.values)
            FilledButton.tonal(
              onPressed: () => MoodiaryKVs.mapTileSource.set(s.name),
              child: Text(s.label),
            ),
        ],
      ),
      _ when !mapAvailable && keyAsync.hasValue => _MapCover(
        message: l10n.mapTiandituNoKey,
        actions: [
          FilledButton.tonal(
            onPressed: () => showMapSourcePicker(context),
            child: Text(l10n.mapSource),
          ),
        ],
      ),
      _ => null,
    };

    return Stack(
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            header,
            const SizedBox(height: 4 + _kCardHeight),
            Padding(
              padding: const .fromLTRB(20, 16, 20, 0),
              child: Text(
                l10n.mapPlaces,
                style: context.theme.typography.titleSmall.emphasized.onSurface,
              ),
            ),
            Expanded(child: list),
          ],
        ),
        _buildMapLayer(
          context,
          fps,
          source: mapAvailable ? source : null,
          tiandituKey: tiandituKey,
          cover: cover,
          headerBottom:
              MediaQuery.paddingOf(context).top + header.preferredSize.height,
        ),
      ],
    );
  }

  Widget _buildMapLayer(
    BuildContext context,
    List<Footprint> fps, {
    required MapTileSource? source,
    required String tiandituKey,
    required Widget? cover,
    required double headerBottom,
  }) {
    final theme = context.theme;
    final insets = MediaQuery.paddingOf(context);
    final interactive = !_expand.isAnimating;
    final map = AnnotatedRegion(
      value: systemOverlayStyleOf(Brightness.light),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCameraFit: _initialFit ??= _fitOf(fps, const .all(36)),
          minZoom: 3,
          maxZoom: 18,
          backgroundColor: theme.colors.surfaceContainer,
          interactionOptions: InteractionOptions(
            flags: interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
          onMapReady: _onMapReady,
          onMapEvent: _onMapEvent,
        ),
        children: [
          if (source != null)
            ...mapTileLayers(
              source,
              tiandituKey: tiandituKey,
              retina: MediaQuery.devicePixelRatioOf(context) > 1,
              onError: _onTileError,
            ),
          MarkerLayer(
            markers: [
              for (final fp in fps)
                Marker(
                  point: _latLng(fp.place),
                  width: 52,
                  height: 52,
                  child: _FootprintPin(
                    count: fp.stat.count,
                    color: placeIconColor(context, fp.place.icon),
                    selected: fp.place.id == _selectedPlaceId,
                    onTap: interactive ? () => _openPlace(fp) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _progress,
      child: map,
      builder: (context, map) {
        final t = _progress.value;
        final card = Offset(_kCardInset, headerBottom + 4) & _cardSize;
        return Positioned.fromRect(
          rect: Rect.lerp(card, Offset.zero & _screen, t)!,
          child: ClipRRect(
            borderRadius: .circular(lerpDouble(theme.radii.lg, 0, t)!),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(ignoring: !interactive, child: map),
                ),
                if (cover != null) Positioned.fill(child: cover),
                if (source != null) ...[
                  Positioned(
                    left: 8,
                    bottom: 8 + insets.bottom * t,
                    child: MapAttribution(source: source),
                  ),
                  if (t < 1)
                    _CardControls(
                      opacity: 1 - const Interval(0, 0.3).transform(t),
                      moved: _cardMoved,
                      onReset: _resetCard,
                      onExpand: _expandMap,
                    ),
                ],
                if (t > 0)
                  _ExpandedControls(
                    opacity: const Interval(0.55, 1).transform(t),
                    enabled: _expand.isCompleted,
                    onBack: _collapse,
                    onFitAll: () =>
                        _animateCamera(_fullOverview(), Durations.medium3),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardControls extends StatelessWidget {
  final double opacity;
  final bool moved;
  final VoidCallback onReset;
  final VoidCallback onExpand;

  const _CardControls({
    required this.opacity,
    required this.moved,
    required this.onReset,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.diary;
    return Positioned(
      top: 10,
      right: 10,
      child: Opacity(
        opacity: opacity,
        child: Row(
          mainAxisSize: .min,
          children: [
            AnimatedSwitcher(
              duration: Durations.short4,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: moved
                  ? Padding(
                      padding: const .only(right: 8),
                      child: MCircleButton(
                        tone: .overlay,
                        elevated: true,
                        size: 36,
                        tooltip: l10n.mapFitAll,
                        icon: const Icon(LucideIcons.scan),
                        onPressed: onReset,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            MCircleButton(
              tone: .overlay,
              elevated: true,
              size: 36,
              tooltip: l10n.mapExpand,
              icon: const Icon(LucideIcons.maximize2),
              onPressed: onExpand,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedControls extends StatelessWidget {
  final double opacity;
  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onFitAll;

  const _ExpandedControls({
    required this.opacity,
    required this.enabled,
    required this.onBack,
    required this.onFitAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.diary;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: opacity,
          child: Row(
            crossAxisAlignment: .start,
            children: [
              MCircleButton(
                tone: .overlay,
                elevated: true,
                size: 44,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: onBack,
              ),
              const Spacer(),
              MCircleButtonGroup(
                items: [
                  MCircleButtonItem(
                    icon: const Icon(LucideIcons.scan),
                    tooltip: l10n.mapFitAll,
                    onPressed: onFitAll,
                  ),
                  MCircleButtonItem(
                    icon: const Icon(LucideIcons.layers),
                    tooltip: l10n.mapSource,
                    onPressed: () => showMapSourcePicker(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FootprintPin extends StatelessWidget {
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _FootprintPin({
    required this.count,
    required this.color,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final single = count == 1 && !selected;
    final size = selected ? 38.0 : (single ? 14.0 : (count < 10 ? 26.0 : 30.0));
    return GestureDetector(
      behavior: .opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: Durations.short4,
          curve: Easing.emphasizedDecelerate,
          padding: .all(selected ? 7 : 0),
          decoration: BoxDecoration(
            shape: .circle,
            color: color.withValues(alpha: selected ? 0.24 : 0),
          ),
          child: AnimatedContainer(
            duration: Durations.short4,
            curve: Easing.emphasizedDecelerate,
            width: size,
            height: size,
            alignment: .center,
            decoration: BoxDecoration(
              color: color,
              shape: .circle,
              border: .all(color: theme.onMedia, width: selected ? 3 : 2),
              boxShadow: MGlassSurface.defaultShadows(theme.colors),
            ),
            child: single
                ? null
                : Text(
                    count > 99 ? '99+' : '$count',
                    maxLines: 1,
                    style: theme.typography.labelSmall.emphasized.onMedia
                        .copyWith(fontFeatures: const [.tabularFigures()]),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final Footprint fp;
  final VoidCallback onTap;

  const _PlaceTile({required this.fp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const .only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surfaceContainerLow,
          borderRadius: .circular(14),
        ),
        child: MInkWell(
          borderRadius: .circular(14),
          onTap: onTap,
          child: Padding(
            padding: const .fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                PlaceBadge(place: fp.place),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    fp.place.name,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: theme.typography.titleMedium.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diary.timelineMonthCount(count: fp.stat.count),
                  style: theme.typography.labelLarge.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceSheet extends ConsumerStatefulWidget {
  final String placeId;

  const _PlaceSheet({required this.placeId});

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  late Future<List<Diary>> _diaries = _load();

  Future<List<Diary>> _load() =>
      getIt<DiaryRepository>().getDiariesAtPlace(widget.placeId);

  @override
  Widget build(BuildContext context) {
    ref.listen(footprintsProvider, (_, next) {
      if (next is! AsyncData<List<Footprint>>) return;
      if (next.value.any((fp) => fp.place.id == widget.placeId)) {
        setState(() => _diaries = _load());
      } else if (ModalRoute.of(context) case final route?) {
        Navigator.of(context).removeRoute(route);
      }
    });
    final fp = ref
        .watch(footprintsProvider)
        .value
        ?.firstWhereOrNull((fp) => fp.place.id == widget.placeId);
    if (fp == null) return const SizedBox.shrink();
    final theme = context.theme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                PlaceBadge(place: fp.place, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        fp.place.name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: theme.typography.titleLarge.emphasized.onSurface,
                      ),
                      Text(
                        '${context.l10n.diary.timelineMonthCount(count: fp.stat.count)} · ${_range(fp.stat.first, fp.stat.last)}',
                        style: theme.typography.labelMedium.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<List<Diary>>(
              future: _diaries,
              builder: (context, snapshot) {
                final list = snapshot.data;
                if (list == null) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: MLoading()),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const .fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      DiaryEntryTile(diary: list[i], showDate: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCover extends StatelessWidget {
  final String message;
  final List<Widget> actions;

  const _MapCover({required this.message, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colors.surfaceContainer,
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Icon(LucideIcons.map, size: 32, color: theme.colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: theme.typography.titleSmall.onSurface),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: .center,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: .only(bottom: context.safeBottom + 96),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colors.surfaceContainer,
              borderRadius: .circular(theme.radii.xl),
            ),
            child: Icon(
              LucideIcons.mapPinned,
              size: 34,
              color: theme.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.diary.mapEmpty,
            style: theme.typography.titleMedium.emphasized.onSurface,
          ),
        ],
      ),
    );
  }
}
