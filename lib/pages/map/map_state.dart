import 'package:latlong2/latlong.dart';
import 'package:mood_diary/common/models/map.dart';
import 'package:mood_diary/utils/utils.dart';

class MapState {
  LatLng? currentLatLng;

  List<DiaryMapItem> diaryMapItemList = [];

  String? tiandituKey = Utils().prefUtil.getValue<String>('tiandituKey');

  MapState();
}
