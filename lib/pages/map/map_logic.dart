import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

import 'map_state.dart';

class MapLogic extends GetxController {
  final MapState state = MapState();

  late final MapController mapController = MapController();

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
  }
}
