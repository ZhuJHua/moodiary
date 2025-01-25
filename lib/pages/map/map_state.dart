import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:moodiary/common/models/map.dart';
import 'package:moodiary/presentation/pref.dart';

class MapState {
  LatLng? currentLatLng;

  List<DiaryMapItem> diaryMapItemList = [];

  String? tiandituKey = PrefUtil.getValue<String>('tiandituKey');

  String vecUrl =
      'http://t6.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=vec&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={key}';
  String cvaUrl =
      'http://t6.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk={key}';

  int random = Random().nextInt(8);

  MapState();
}
