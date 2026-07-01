import 'package:latlong2/latlong.dart';

class DiaryMapItem {
  late LatLng latLng;
  late int id;
  late String coverImageName;

  DiaryMapItem(this.latLng, this.id, this.coverImageName);
}
