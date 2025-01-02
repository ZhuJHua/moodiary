import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' as flutter;
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/components/local_send/local_send_logic.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../../../pages/home/diary/diary_logic.dart';
import '../../../utils/data/isar.dart';
import '../../../utils/file_util.dart';
import '../../../utils/log_util.dart';
import 'local_send_server_state.dart';

class LocalSendServerLogic extends GetxController {
  final LocalSendServerState state = LocalSendServerState();
  late RawDatagramSocket socket;
  HttpServer? httpServer;

  @override
  void onReady() async {
    socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, state.scanPort);
    state.serverIp = await getDeviceIP();
    update();
    if (state.serverIp != null) {
      await startBroadcastListener();
      await startServer();
    }
    super.onReady();
  }

  @override
  void onClose() {
    socket.close();
    httpServer?.close(force: true);
    super.onClose();
  }

  // 启动UDP广播监听
  Future<void> startBroadcastListener() async {
    LogUtil.printInfo('Listening for broadcast on port ${state.scanPort}');
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final message = String.fromCharCodes(datagram.data);
          LogUtil.printInfo(
              'Received broadcast: $message from ${datagram.address.address}');
          final response =
              '${state.serverIp}:${state.transferPort}:${state.serverName}';
          socket.send(response.codeUnits, datagram.address, datagram.port);
        }
      }
    });
  }

  // 启动HTTP服务器
  Future<void> startServer() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);
    httpServer = await serve(handler, state.serverIp!, state.transferPort);
    LogUtil.printInfo(
        'Server started on http://${state.serverIp}:${state.transferPort}');
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    late Diary diary;
    String? categoryName;
    // 处理表单数据
    if (request.formData() case var form?) {
      await for (final formData in form.formData) {
        final name = formData.name;
        // 读取日记 JSON 数据
        if (name == 'diary') {
          diary = await flutter.compute(
              Diary.fromJson,
              jsonDecode(await formData.part.readString())
                  as Map<String, dynamic>);
        } else if (name == 'image' ||
            name == 'video' ||
            name == 'thumbnail' ||
            name == 'audio') {
          if (formData.filename != null) {
            // 写入文件到目录
            File file;
            if (name == 'thumbnail') {
              file = File(FileUtil.getRealPath('video', formData.filename!));
            } else {
              file = File(FileUtil.getRealPath(name, formData.filename!));
            }

            final sink = file.openWrite();
            await formData.part.pipe(sink);
            await sink.close();
          }
          // 如果有分类
        } else if (name == 'categoryName') {
          categoryName = await formData.part.readString();
        }
      }
    }
    // 如果分类不为空，插入一个分类
    if (categoryName != null) {
      await IsarUtil.updateACategory(Category()
        ..id = diary.categoryId!
        ..categoryName = categoryName);
    }
    // 插入日记
    await IsarUtil.insertADiary(diary);
    await Bind.find<DiaryLogic>().refreshAll();
    state.receiveCount.value += 1;
    return shelf.Response.ok('Data and files received successfully');
  }
}
