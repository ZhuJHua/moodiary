import 'package:drift/drift.dart' show Value;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

Place make(
  String id,
  String name, {
  double lat = 30.2841,
  double lon = 120.1552,
  String? icon,
}) => Place(
  id: id,
  name: name,
  latitude: lat,
  longitude: lon,
  icon: icon,
  lastModified: DateTime.utc(2026, 9, 5),
);

Future<void> insertDiary(
  MoodiaryDatabase db,
  String id,
  String? placeId, {
  int time = 0,
  int? lastModified,
  bool show = true,
}) => db
    .into(db.diaries)
    .insert(
      DiariesCompanion.insert(
        id: id,
        title: '',
        content: '',
        contentText: '',
        time: time,
        lastModified: lastModified ?? time,
        show: show ? 1 : 0,
        moodLevel: Value(DiaryMood.okay.score),
        type: 'tiptap',
        placeId: Value(placeId),
      ),
    );

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);
