import 'package:latlong2/latlong.dart';
import 'package:mood_diary/utils/utils.dart';

class MapState {
  late LatLng? currentLatLng;

  String? tiandituKey = Utils().prefUtil.getValue<String>('tiandituKey');

  MapState() {
    currentLatLng = null;
  }
}
