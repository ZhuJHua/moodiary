import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary/common/models/geo.dart';
import 'package:moodiary/common/models/github.dart';
import 'package:moodiary/common/models/hitokoto.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/image.dart';
import 'package:moodiary/common/models/weather.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/http_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/signature_util.dart';
import 'package:refreshed/refreshed.dart';

class Api {
  static Future<Stream<String>?> getHunYuan(
      String id, String key, List<Message> messages, int model) async {
    //获取时间戳
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hunyuanModel = switch (model) {
      0 => 'hunyuan-lite',
      1 => 'hunyuan-standard',
      2 => 'hunyuan-pro',
      3 => 'hunyuan-turbo',
      _ => 'hunyuan-lite',
    };
    //请求正文
    final body = {
      'Model': hunyuanModel,
      'Messages': messages.map((value) => value.toMap()).toList(),
      'Stream': true,
    };

    //获取签名
    final authorization =
        SignatureUtil.generateSignature(id, key, timestamp, body);
    //构造请求头
    final header = PublicHeader(
        'ChatCompletions', timestamp ~/ 1000, '2023-09-01', authorization);
    //发起请求
    return await HttpUtil().postStream('https://hunyuan.tencentcloudapi.com',
        header: header.toMap(), data: body);
  }

  static Future<Uint8List?> getImageData(String url) async {
    return (await HttpUtil().get(url, type: ResponseType.bytes)).data;
  }

  static Future<List<String>?> updatePosition() async {
    Position? position;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        NoticeUtil.showToast(l10n.noticeEnableLocation);
        return null;
      }
      if (permission == LocationPermission.deniedForever) {
        NoticeUtil.showToast(l10n.noticeEnableLocation2);
        return null;
      }
    }
    if (await Geolocator.isLocationServiceEnabled()) {
      position = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true);
      position ??= await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(forceLocationManager: true));
    }
    if (position != null) {
      final local = Localizations.localeOf(Get.context!);
      final parameters = {
        'location':
            '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
        'key': PrefUtil.getValue<String>('qweatherKey'),
        'lang': local
      };
      final res = await HttpUtil().get(
          'https://geoapi.qweather.com/v2/city/lookup',
          parameters: parameters);
      final geo =
          await compute(GeoResponse.fromJson, res.data as Map<String, dynamic>);
      if (geo.location != null && geo.location!.isNotEmpty) {
        final city = geo.location!.first;
        return [
          position.latitude.toString(),
          position.longitude.toString(),
          '${city.adm2} ${city.name}'
        ];
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  static Future<List<String>?> updateWeather({required LatLng position}) async {
    final local = Localizations.localeOf(Get.context!);
    final parameters = {
      'location':
          '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
      'key': PrefUtil.getValue<String>('qweatherKey'),
      'lang': local
    };
    final res = await HttpUtil().get(
        'https://devapi.qweather.com/v7/weather/now',
        parameters: parameters);
    final weather = await compute(
        WeatherResponse.fromJson, res.data as Map<String, dynamic>);
    if (weather.now != null) {
      return [
        weather.now!.icon!,
        weather.now!.temp!,
        weather.now!.text!,
      ];
    } else {
      return null;
    }
  }

  static Future<GithubRelease?> getGithubRelease() async {
    final res = await HttpUtil()
        .get('https://api.github.com/repos/ZhuJHua/moodiary/releases/latest');
    if (res.data != null) {
      final githubRelease = await compute(
          GithubRelease.fromJson, res.data as Map<String, dynamic>);
      return githubRelease;
    }
    return null;
  }

  static Future<List<String>?> updateHitokoto() async {
    final res = await HttpUtil().get('https://v1.hitokoto.cn');
    final hitokoto = await compute(
        HitokotoResponse.fromJson, res.data as Map<String, dynamic>);
    return [hitokoto.hitokoto!];
  }

  static Future<List<String>?> updateImageUrl() async {
    final res = await HttpUtil()
        .get('https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1');
    final BingImage bingImage =
        await compute(BingImage.fromJson, res.data as Map<String, dynamic>);
    return ['https://cn.bing.com${bingImage.images?[0].url}'];
  }
}
