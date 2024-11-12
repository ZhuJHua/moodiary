import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:mood_diary/pages/diary_details/diary_details_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';

import 'map_state.dart';

class MapLogic extends GetxController {
  final MapState state = MapState();

  late final MapController mapController = MapController();

  @override
  void onReady() async {
    state.currentLatLng = await getLocation();
    await getAllItem();
    update();
    super.onReady();
  }

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
  }

  Future<LatLng?> getLocation() async {
    if (await Utils().permissionUtil.checkPermission(Permission.location)) {
      Position? position;
      position = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
      position ??= await Geolocator.getCurrentPosition(locationSettings: AndroidSettings(forceLocationManager: true));
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }

  Future<void> getAllItem() async {
    state.diaryMapItemList = await Utils().isarUtil.getAllMapItem();
  }

  Future<void> toCurrentPosition() async {
    Utils().noticeUtil.showToast('定位中');
    var currentPosition = await getLocation();
    Utils().logUtil.printInfo(currentPosition.toString());
    Utils().noticeUtil.showToast('定位成功');
    mapController.move(currentPosition!, mapController.camera.maxZoom!);
  }

  Future<void> toDiaryPage({required int isarId}) async {
    await HapticFeedback.mediumImpact();
    var diary = await Utils().isarUtil.getDiaryByID(isarId);
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary!.id);
    await Get.toNamed(
      AppRoutes.diaryPage,
      arguments: [diary, false],
    );
  }
}
