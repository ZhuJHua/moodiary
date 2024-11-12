import 'package:latlong2/latlong.dart';

class DiaryMapItem {
  // 坐标
  late LatLng latLng;

  // 文章id
  late int id;

  // 封面图片名称
  late String coverImageName;

  DiaryMapItem(this.latLng, this.id, this.coverImageName);
}
