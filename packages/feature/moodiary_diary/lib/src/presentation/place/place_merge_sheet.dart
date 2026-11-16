import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import '../map/map_tile_source.dart';
import '../map/map_tiles.dart';
import 'place_editor.dart';

Future<({String keptId, String name})?> showPlaceMergeSheet(
  BuildContext context, {
  required List<Place> candidates,
}) {
  return MSheet.show<({String keptId, String name})>(
    context,
    builder: (_) => _PlaceMergeSheet(candidates: candidates),
  );
}

class _PlaceMergeSheet extends ConsumerStatefulWidget {
  final List<Place> candidates;

  const _PlaceMergeSheet({required this.candidates});

  @override
  ConsumerState<_PlaceMergeSheet> createState() => _PlaceMergeSheetState();
}

class _PlaceMergeSheetState extends ConsumerState<_PlaceMergeSheet> {
  late String _keptId = widget.candidates.first.id;
  late final _controller = TextEditingController(
    text: widget.candidates.first.name,
  );
  bool _nameEdited = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _finalName => _controller.text.trim();

  void _select(Place place) {
    setState(() {
      _keptId = place.id;
      if (!_nameEdited) _controller.text = place.name;
    });
  }

  Future<bool> _confirm() async {
    if (_finalName.isEmpty) {
      setState(() => _nameEdited = true);
      return false;
    }
    final l10n = context.l10n;
    final controller = ref.read(placeControllerProvider.notifier);
    final affectedCount = await controller.affectedDiaryCount([
      for (final place in widget.candidates) place.id,
    ]);
    if (!mounted) return false;
    return MAlert.confirm(
      context,
      title: l10n.diary.placeMergeConfirmTitle,
      message: l10n.diary.placeMergeConfirmMessage(
        name: _finalName,
        count: widget.candidates.length,
        diaries: affectedCount,
      ),
      confirmLabel: l10n.diary.placeMerge,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = MapTileSource.of(MoodiaryKVs.mapTileSource.get()!);
    final tiandituKey =
        ref.watch(secretKvProvider(MoodiarySecureKVs.tiandituKey)).value ?? '';

    return ListenableBuilder(
      listenable: _controller,
      child: _buildChoices(source, tiandituKey),
      builder: (context, child) =>
          MSheetScaffold<({String keptId, String name})>(
            title: context.l10n.diary.placeMergeSheetTitle,
            subtitle: context.l10n.diary.placeMergeSheetSubtitle(
              count: widget.candidates.length - 1,
            ),
            actions: [
              MAction(label: context.l10n.common.cancel),
              MAction(
                label: context.l10n.diary.placeMerge,
                isPrimary: true,
                value: (keptId: _keptId, name: _finalName),
                onSubmit: _confirm,
              ),
            ],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                child!,
                const SizedBox(height: 12),
                MField(
                  controller: _controller,
                  label: context.l10n.diary.placeMergeNameLabel,
                  errorText: _nameEdited && _finalName.isEmpty
                      ? context.l10n.diary.placeNameEmpty
                      : null,
                  autofocus: !mapAvailable(source, tiandituKey),
                  textInputAction: .done,
                  onChanged: (_) {
                    if (!_nameEdited) setState(() => _nameEdited = true);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildChoices(MapTileSource? source, String tiandituKey) {
    final showMap = mapAvailable(source, tiandituKey);
    final footprints = ref.watch(placeFootprintsProvider).value ?? const {};
    final kept = widget.candidates.firstWhere((place) => place.id == _keptId);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (showMap) ...[
          _buildMap(source!, tiandituKey),
          const SizedBox(height: 12),
        ],
        MFormSection(context.l10n.diary.placeMergeKeepLabel),
        const SizedBox(height: 6),
        for (final place in widget.candidates)
          MSheetOptionTile<String>(
            option: MSheetOption(
              value: place.id,
              leading: PlaceBadge(place: place, size: 32),
              label: place.name,
              subtitle: _candidateSubtitle(
                place,
                kept,
                footprints[place.id]?.count ?? 0,
              ),
            ),
            selected: place.id == _keptId,
            onTap: () => _select(place),
          ),
      ],
    );
  }

  String _candidateSubtitle(Place place, Place kept, int count) {
    final countLabel = placeCountLabel(context, count);
    if (place.id == kept.id) return countLabel;
    final meters = distanceMeters(
      kept.latitude,
      kept.longitude,
      place.latitude,
      place.longitude,
    );
    final distanceLabel = context.l10n.diary.placeDistanceAway(
      distance: formatDistance(context, meters),
    );
    return '$countLabel · $distanceLabel';
  }

  Widget _buildMap(MapTileSource source, String tiandituKey) {
    final theme = context.theme;
    return SizedBox(
      height: 160,
      child: ClipRRect(
        borderRadius: .circular(theme.radii.lg),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [
                    for (final place in widget.candidates)
                      LatLng(place.latitude, place.longitude),
                  ],
                  padding: const EdgeInsets.all(48),
                  maxZoom: 17,
                ),
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: theme.colors.surfaceContainerHighest,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                ...mapTileLayers(
                  source,
                  tiandituKey: tiandituKey,
                  retina: MediaQuery.devicePixelRatioOf(context) > 1,
                ),
                MarkerLayer(
                  markers: [
                    for (final p in widget.candidates)
                      Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 42,
                        height: 42,
                        child: GestureDetector(
                          onTap: () => _select(p),
                          child: Center(
                            child: PlaceMarker(
                              place: p,
                              size: 30,
                              selected: p.id == _keptId,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: MapAttribution(source: source),
            ),
          ],
        ),
      ),
    );
  }
}
