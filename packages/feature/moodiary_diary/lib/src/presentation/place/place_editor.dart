import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

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
  final contentKey = GlobalKey<_PlaceEditorContentState>();
  final confirmed = await MAlert.show<bool>(
    context,
    title: existing == null
        ? context.l10n.diary.placeCreateTitle
        : context.l10n.diary.placeEditTitle,
    content: _PlaceEditorContent(
      key: contentKey,
      draft: draft,
      excludeId: existing?.id,
      canRelocate: existing != null,
    ),
    actions: [
      MAction(label: context.l10n.common.cancel, value: false),
      MAction(
        label: context.l10n.common.ok,
        value: true,
        isPrimary: true,
        onSubmit: () =>
            contentKey.currentState?.submit() ?? Future.value(false),
      ),
    ],
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

class _PlaceEditorContent extends ConsumerStatefulWidget {
  final _PlaceDraft draft;

  final String? excludeId;

  final bool canRelocate;

  const _PlaceEditorContent({
    super.key,
    required this.draft,
    required this.excludeId,
    required this.canRelocate,
  });

  @override
  ConsumerState<_PlaceEditorContent> createState() =>
      _PlaceEditorContentState();
}

class _PlaceEditorContentState extends ConsumerState<_PlaceEditorContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.name,
  );

  bool _edited = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    if (widget.draft.name.trim().isEmpty) {
      if (!_edited) setState(() => _edited = true);
      return false;
    }
    if (widget.draft.latitude != null && !widget.draft.relocate) return true;
    final result = await LocationService.current(precise: true);
    if (!mounted) return false;
    final failure = result.failure;
    if (failure != null) {
      toast.error(message: _failureMessage(failure));
      return false;
    }
    setState(() {
      widget.draft.latitude = result.latitude;
      widget.draft.longitude = result.longitude;
    });
    return true;
  }

  String _failureMessage(LocationFailure failure) => switch (failure) {
    LocationFailure.permissionDenied => l10n.diary.positionPermissionDenied,
    LocationFailure.permissionDeniedForever =>
      l10n.diary.positionPermissionForever,
    LocationFailure.serviceOff => l10n.diary.positionServiceOff,
    LocationFailure.unavailable => l10n.diary.positionFailed,
  };

  String? _overlapWarning(List<Place> places) {
    final lat = widget.draft.latitude;
    final lon = widget.draft.longitude;
    if (lat == null || lon == null) return null;
    for (final other in places) {
      if (other.id == widget.excludeId) continue;
      final d = distanceMeters(lat, lon, other.latitude, other.longitude);
      if (d < 2 * Place.matchRadius) {
        return context.l10n.diary.placeOverlapWarning(
          name: other.name,
          distance: formatDistance(context, d),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final places = ref.watch(placeControllerProvider).value ?? const <Place>[];
    final warning = _overlapWarning(places);
    OutlineInputBorder border([BorderSide side = .none]) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: side,
    );
    final labelStyle = theme.typography.labelMedium.onSurfaceVariant;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: .done,
          onChanged: (value) => setState(() {
            _edited = true;
            widget.draft.name = value;
          }),
          style: theme.typography.bodyLarge.onSurface,
          decoration: InputDecoration(
            labelText: context.l10n.diary.placeNameLabel,
            errorText: _edited && widget.draft.name.trim().isEmpty
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
        Text(context.l10n.diary.placeIconLabel, style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in kPlaceIcons)
              MInkWell(
                onTap: () => setState(() => widget.draft.icon = name),
                borderRadius: .circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.draft.icon == name
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: .circular(12),
                  ),
                  child: Icon(
                    placeIconOf(name),
                    size: 20,
                    color: widget.draft.icon == name
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (widget.canRelocate) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.diary.placeRelocate,
                  style: theme.typography.bodyMedium.onSurface,
                ),
              ),
              Switch(
                value: widget.draft.relocate,
                onChanged: (v) => setState(() => widget.draft.relocate = v),
              ),
            ],
          ),
        ],
        if (warning != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: .start,
            children: [
              Icon(LucideIcons.triangleAlert, size: 16, color: colors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(warning, style: theme.typography.bodySmall.error),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
