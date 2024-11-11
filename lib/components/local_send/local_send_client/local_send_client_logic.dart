import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';

import 'local_send_client_state.dart';

class LocalSendClientLogic extends GetxController {
  final LocalSendClientState state = LocalSendClientState();

  late RawDatagramSocket socket;
  Timer? timer;

  @override
  void onReady() async {
    super.onReady();
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    await startFindServer();
  }

  @override
  void onClose() {
    socket.close();
    timer?.cancel();
    super.onClose();
  }

  void _sendBroadcast() {
    const message = 'Looking for server';
    socket.send(message.codeUnits, InternetAddress('255.255.255.255'), state.scanPort);
    Utils().logUtil.printInfo('Broadcast sent');
  }

  // 尝试在 30 秒内找到服务器
  Future<bool> startFindServer() async {
    state.isFindingServer = true;
    update();

    final found = await _findServer(timeout: const Duration(seconds: 30));

    if (found) {
    } else {
      state.isFindingServer = false;
      update();
    }
    return found;
  }

  // 重新开始查找服务器
  Future<void> restartFindServer() async {
    // 确保之前的监听已停止
    timer?.cancel();
    socket.close();

    // 重新初始化 socket 和监听
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    await startFindServer();
  }

  Future<bool> _findServer({required Duration timeout}) async {
    final completer = Completer<bool>();

    // 启动 30 秒超时定时器
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        timer?.cancel();
        completer.complete(false);
      }
    });

    // 轮询发送广播消息
    timer = Timer.periodic(state.broadcastInterval, (timer) {
      _sendBroadcast();
    });

    // 监听服务器响应
    socket.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final serverResponse = String.fromCharCodes(datagram.data);
          Utils().logUtil.printInfo('Found server: $serverResponse');

          final serverInfo = serverResponse.split(':');
          state.serverIp = serverInfo[0];
          state.serverPort = int.parse(serverInfo[1]);
          state.serverName = serverInfo[2];
          state.isFindingServer = false;
          update();

          timer?.cancel();
          socket.close();

          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      }
    });

    // 初次发送广播
    _sendBroadcast();

    return completer.future;
  }

  // 向服务器发送数据并监听进度
  Future<void> sendData(Diary diary) async {
    state.isSending.value = true;
    // 创建 FormData 并同步添加 JSON 和文件
    dio.FormData formData = dio.FormData();
    // 添加 JSON 数据
    formData.fields.add(MapEntry('diary', jsonEncode(diary.toJson())));
    // 如果有分类，把分类名字带过去
    if (diary.categoryId != null) {
      var categoryName = Utils().isarUtil.getCategoryName(diary.categoryId!)!.categoryName;
      formData.fields.add(MapEntry('categoryName', categoryName));
    }
    // 同步添加图片文件
    for (var imageName in diary.imageName) {
      final filePath = Utils().fileUtil.getRealPath('image', imageName);
      formData.files.add(MapEntry(
        'image',
        await dio.MultipartFile.fromFile(filePath, filename: imageName),
      ));
    }
    // 同步添加视频文件
    for (var videoName in diary.videoName) {
      final filePath = Utils().fileUtil.getRealPath('video', videoName);
      formData.files.add(MapEntry(
        'video',
        await dio.MultipartFile.fromFile(filePath, filename: videoName),
      ));
    }
    // 同步添加缩略图文件
    for (var videoName in diary.videoName) {
      final filePath = Utils().fileUtil.getRealPath('thumbnail', videoName);
      formData.files.add(MapEntry(
        'thumbnail',
        await dio.MultipartFile.fromFile(filePath, filename: 'thumbnail-${videoName.substring(6, 42)}.jpeg'),
      ));
    }
    // 同步添加音频文件
    for (var audioName in diary.audioName) {
      final filePath = Utils().fileUtil.getRealPath('audio', audioName);
      formData.files.add(MapEntry(
        'audio',
        await dio.MultipartFile.fromFile(filePath, filename: audioName),
      ));
    }
    final startTime = DateTime.now();
    // 发送请求并监听进度
    var response = await Utils().httpUtil.dio.post(
      'http://${state.serverIp}:${state.serverPort}',
      data: formData,
      onSendProgress: (int sent, int total) {
        final currentTime = DateTime.now();
        final timeElapsed = currentTime.difference(startTime).inMilliseconds / 1000;
        state.speed.value = sent / timeElapsed;
        state.progress.value = sent / total;
      },
    );
    if (response.statusCode == 200 && response.data != null) {
    } else {
      Utils().noticeUtil.showToast('发送失败');
    }
    state.sendCount.value += 1;
  }

  Future<void> sendDiaryList() async {
    if (state.diaryToSend.isNotEmpty) {
      for (var diary in state.diaryToSend) {
        await sendData(diary);
        state.progress.value = .0;
      }
      state.sendCount.value = 0;
      state.diaryToSend.clear();
      state.isSending.value = false;
      Utils().noticeUtil.showToast('发送完成');
    } else {
      Utils().noticeUtil.showToast('还没选择日记');
    }
  }

  // 向服务器发送数据并监听进度
  Future<void> sendAllData() async {
    state.isSending.value = true;
    final dataPath = Utils().fileUtil.getRealPath('', '');
    final zipPath = Utils().fileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    // 获取压缩文件路径
    var filePath = await compute(Utils().fileUtil.zipFile, isolateParams);

    // 创建 FormData 并同步添加 JSON 和文件
    dio.FormData formData = dio.FormData();
    // 添加 JSON 数据
    formData.files.add(MapEntry('file', await dio.MultipartFile.fromFile(filePath)));

    final startTime = DateTime.now();
    // 发送请求并监听进度
    var response = await Utils().httpUtil.dio.post(
      'http://${state.serverIp}:${state.serverPort}',
      data: formData,
      onSendProgress: (int sent, int total) {
        final currentTime = DateTime.now();
        final timeElapsed = currentTime.difference(startTime).inMilliseconds / 1000;
        state.speed.value = sent / timeElapsed;
        state.progress.value = sent / total;
      },
    );
    state.isSending.value = false;
    if (response.statusCode == 200 && response.data != null) {
      if (response.data as String == 'Data and files received successfully') {
        Utils().noticeUtil.showToast('发送成功');
      }
    } else {
      Utils().noticeUtil.showToast('发送失败');
    }
  }

  Future<void> setDiary(Duration duration) async {
    Get.backLegacy();
    var now = DateTime.now();
    state.diaryToSend.value = await Utils().isarUtil.getDiariesByDateRange(now.subtract(duration), now);
  }

  Future<void> setAllDiary() async {
    Get.backLegacy();
    state.diaryToSend.value = await Utils().isarUtil.getAllDiaries();
  }
}
