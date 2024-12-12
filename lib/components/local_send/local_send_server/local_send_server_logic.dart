import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/components/local_send/local_send_logic.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../../../pages/home/diary/diary_logic.dart';
import 'local_send_server_state.dart';

class LocalSendServerLogic extends GetxController {
  final LocalSendServerState state = LocalSendServerState();
  late RawDatagramSocket socket;
  HttpServer? httpServer;

  @override
  void onReady() async {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, state.scanPort);
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
    Utils().logUtil.printInfo('Listening for broadcast on port ${state.scanPort}');
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final message = String.fromCharCodes(datagram.data);
          Utils().logUtil.printInfo('Received broadcast: $message from ${datagram.address.address}');
          final response = '${state.serverIp}:${state.transferPort}:${state.serverName}';
          socket.send(response.codeUnits, datagram.address, datagram.port);
        }
      }
    });
  }

  // 启动HTTP服务器
  Future<void> startServer() async {
    final handler = const shelf.Pipeline().addMiddleware(shelf.logRequests()).addHandler(_handleRequest);
    httpServer = await serve(handler, state.serverIp!, state.transferPort);
    Utils().logUtil.printInfo('Server started on http://${state.serverIp}:${state.transferPort}');
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
          diary = Diary.fromJson(jsonDecode(await formData.part.readString()));
        } else if (name == 'image' || name == 'video' || name == 'thumbnail' || name == 'audio') {
          if (formData.filename != null) {
            // 写入文件到目录
            File file;
            if (name == 'thumbnail') {
              file = File(Utils().fileUtil.getRealPath('video', formData.filename!));
            } else {
              file = File(Utils().fileUtil.getRealPath(name, formData.filename!));
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
      await Utils().isarUtil.insertACategory(Category()
        ..id = diary.categoryId!
        ..categoryName = categoryName);
    }
    // 插入日记
    await Utils().isarUtil.insertADiary(diary);
    await Bind.find<DiaryLogic>().refreshAll();
    state.receiveCount.value += 1;
    return shelf.Response.ok('Data and files received successfully');
  }

  Future<shelf.Response> _handleAllData(shelf.Request request) async {
    // 处理表单数据
    if (request.formData() case var form?) {
      await for (final formData in form.formData) {
        final name = formData.name;
        if (formData.filename != null) {
          final tempFile = File(Utils().fileUtil.getCachePath(formData.filename!));
          final sink = tempFile.openWrite();
          await formData.part.pipe(sink);
          await sink.close();
          await Utils().fileUtil.extractFile(tempFile.path);
        }
      }
    }
    return shelf.Response.ok('Data and files received successfully');
  }
}
