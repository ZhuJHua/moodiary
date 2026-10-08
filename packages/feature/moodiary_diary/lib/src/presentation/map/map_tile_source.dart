import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

enum MapTileSource {
  osm,
  tianditu;

  static MapTileSource? of(String name) => values.asNameMap()[name];

  String get label => switch (this) {
    osm => 'OpenStreetMap',
    tianditu => l10n.diary.mapSourceTianditu,
  };
}

Future<void> showMapSourcePicker(BuildContext context) async {
  final current = MapTileSource.of(MoodiaryKVs.mapTileSource.get()!);
  final picked = await MSheet.picker<MapTileSource>(
    context,
    title: context.l10n.diary.mapSource,
    selected: current,
    options: [
      for (final source in MapTileSource.values)
        MSheetOption(value: source, label: source.label),
    ],
  );
  if (picked != null) MoodiaryKVs.mapTileSource.set(picked.name);
}
