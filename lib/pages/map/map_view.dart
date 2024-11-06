import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/bubble/bubble_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'map_logic.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<MapLogic>();
    final state = Bind.find<MapLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('足迹'),
      ),
      body: GetBuilder<MapLogic>(
        builder: (_) {
          return state.currentLatLng != null && state.tiandituKey != null
              ? FlutterMap(
                  mapController: logic.mapController,
                  options:
                      MapOptions(initialCenter: state.currentLatLng!, minZoom: 4.0, initialZoom: 16.0, maxZoom: 18.0),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'http://t${Random().nextInt(8)}.tianditu.gov.cn/vec_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=img&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=${state.tiandituKey}',
                      tileProvider: const FMTCStore('mapStore').getTileProvider(),
                    ),
                    TileLayer(
                      urlTemplate:
                          'http://t${Random().nextInt(8)}.tianditu.gov.cn/cva_w/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=cva&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&tk=${state.tiandituKey}',
                      tileProvider: const FMTCStore('mapStore').getTileProvider(),
                    ),
                    MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                            markers: List.generate(state.diaryMapItemList.length, (index) {
                              return Marker(
                                  point: state.diaryMapItemList[index].latLng,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await logic.toDiaryPage(isarId: state.diaryMapItemList[index].id);
                                    },
                                    child: Bubble(
                                        backgroundColor: colorScheme.tertiary,
                                        borderRadius: 8,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            image: DecorationImage(
                                                image: FileImage(File(Utils().fileUtil.getRealPath(
                                                    'image', state.diaryMapItemList[index].coverImageName))),
                                                fit: BoxFit.cover),
                                          ),
                                        )),
                                  ),
                                  width: 56,
                                  height: 64);
                            }),
                            rotate: true,
                            maxZoom: 18.0,
                            forceIntegerZoomLevel: true,
                            showPolygon: false,
                            builder: (context, markers) {
                              return Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: colorScheme.tertiaryContainer,
                                    border: Border.all(color: colorScheme.tertiary, width: 2)),
                                child: Center(
                                  child: Text(
                                    markers.length.toString(),
                                    style: TextStyle(color: colorScheme.onTertiaryContainer),
                                  ),
                                ),
                              );
                            })),
                  ],
                )
              : const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          logic.toCurrentPosition();
        },
        child: const FaIcon(FontAwesomeIcons.locationCrosshairs),
      ),
    );
  }
}
