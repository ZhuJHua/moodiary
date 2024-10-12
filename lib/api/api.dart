import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/hitokoto.dart';
import 'package:mood_diary/common/models/hunyuan.dart';
import 'package:mood_diary/common/models/image.dart';
import 'package:mood_diary/common/models/weather.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';

class Api {
  Api._();

  static final Api _instance = Api._();

  factory Api() => _instance;

  Future<Stream<String>?> getHunYuan(String id, String key, List<Message> messages, int model) async {
    //获取时间戳
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var hunyuanModel = switch (model) {
      0 => 'hunyuan-lite',
      1 => 'hunyuan-standard',
      2 => 'hunyuan-pro',
      3 => 'hunyuan-turbo',
      _ => 'hunyuan-lite',
    };
    //请求正文
    var body = {
      'Model': hunyuanModel,
      'Messages': messages.map((value) => value.toMap()).toList(),
      'Stream': true,
    };

    //获取签名
    var authorization = Utils().signatureUtil.generateSignature(id, key, timestamp, body);
    //构造请求头
    var header = PublicHeader('ChatCompletions', timestamp ~/ 1000, '2023-09-01', authorization);
    //发起请求
    return await Utils().httpUtil.postStream('https://hunyuan.tencentcloudapi.com', header: header.toMap(), data: body);
  }

  Future<Uint8List?> getImageData(String url) async {
    return (await Utils().httpUtil.get(url, type: ResponseType.bytes)).data;
  }

  Future<List<String>?> updateWeather() async {
    Position? position;

    if (await Utils().permissionUtil.checkPermission(Permission.location)) {
      position = await Geolocator.getCurrentPosition(locationSettings: AndroidSettings(forceLocationManager: true));
    }

    if (position != null) {
      var local = Localizations.localeOf(Get.context!);
      var parameters = {
        'location':
            '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.altitude.toStringAsFixed(2))}',
        'key': Utils().prefUtil.getValue<String>('qweatherKey'),
        'lang': local
      };
      var res = await Utils().httpUtil.get('https://devapi.qweather.com/v7/weather/now', parameters: parameters);
      var weather = await compute(WeatherResponse.fromJson, res.data as Map<String, dynamic>);
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
    return null;
  }

  Future<List<String>?> updateHitokoto() async {
    var res = await Utils().httpUtil.get('https://v1.hitokoto.cn');
    var hitokoto = await compute(HitokotoResponse.fromJson, res.data as Map<String, dynamic>);
    return [hitokoto.hitokoto!];
  }

  Future<List<String>?> updateImageUrl() async {
    var res = await Utils().httpUtil.get('https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1');
    BingImage bingImage = await compute(BingImage.fromJson, res.data as Map<String, dynamic>);
    return ['https://cn.bing.com${bingImage.images?[0].url}'];
  }
}
