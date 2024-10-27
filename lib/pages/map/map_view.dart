import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

import 'map_logic.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<MapLogic>();
    final state = Bind.find<MapLogic>().state;

    return FlutterMap(
      children: [TileLayer()],
      mapController: logic.mapController,
      options: const MapOptions(),
    );
  }
}
