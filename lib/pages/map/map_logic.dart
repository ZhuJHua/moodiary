import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'map_state.dart';

class MapLogic extends GetxController {
  final MapState state = MapState();

  late final MapController mapController = MapController();

  @override
  void onReady() async {
    state.currentLatLng = await getLocation();
    update();
    super.onReady();
  }

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
  }

  Future<LatLng> getLocation() async {
    Position? position;
    position = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    position ??= await Geolocator.getCurrentPosition(locationSettings: AndroidSettings(forceLocationManager: true));
    return LatLng(position.latitude, position.longitude);
  }
}
