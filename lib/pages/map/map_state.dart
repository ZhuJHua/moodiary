import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:mood_diary/common/models/map.dart';

import '../../utils/data/pref.dart';

class MapState {
  LatLng? currentLatLng;

  List<DiaryMapItem> diaryMapItemList = [];

  String? tiandituKey = PrefUtil.getValue<String>('tiandituKey');

  int random = Random().nextInt(8);

  MapState();
}
