import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:get/get.dart';

import 'map_logic.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<MapLogic>();
    final state = Bind.find<MapLogic>().state;

    return GetBuilder<MapLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return state.currentLatLng != null
            ? FlutterMap(
                mapController: logic.mapController,
                options: MapOptions(initialCenter: state.currentLatLng!),
                children: [
                  TileLayer(
                    urlTemplate:
                        'http://t6.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=img&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
                    tileProvider: const FMTCStore('mapStore').getTileProvider(),
                  ),
                  TileLayer(
                    urlTemplate:
                        'http://t6.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=',
                    tileProvider: const FMTCStore('mapStore').getTileProvider(),
                  ),
                ],
              )
            : const CircularProgressIndicator();
      },
    );
  }
}
