import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import 'local_send_server_state.dart';

class LocalSendServerLogic extends GetxController {
  final LocalSendServerState state = LocalSendServerState();
  late RawDatagramSocket socket;
  HttpServer? httpServer;

  late final networkInfo = NetworkInfo();

  @override
  void onReady() async {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, state.scanPort);
    state.serverIp = await networkInfo.getWifiIP();
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
          final response = '${state.serverIp}:${state.transferPort}';
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
    List<File> images = [];
    List<File> videos = [];
    List<File> thumbnails = [];
    List<File> audios = [];

    // 处理表单数据
    if (request.formData() case var form?) {
      await for (final formData in form.formData) {
        final name = formData.name;
        // 读取日记 JSON 数据
        if (name == 'diary') {
          diary = Diary.fromJson(jsonDecode(await formData.part.readString()));
        } else if (name == 'image' || name == 'video' || name == 'thumbnail' || name == 'audio') {
          if (formData.filename != null) {
            final tempFile = File(Utils().fileUtil.getCachePath(formData.filename!));
            final sink = tempFile.openWrite();
            await formData.part.pipe(sink);
            await sink.close();

            // 分类文件
            if (name == 'image') images.add(tempFile);
            if (name == 'video') videos.add(tempFile);
            if (name == 'thumbnail') thumbnails.add(tempFile);
            if (name == 'audio') audios.add(tempFile);
          }
        }
      }
    }
    return shelf.Response.ok('Data and files received successfully');
  }

// 辅助函数，用于按块保存文件并调用进度更新回调
  Future<File> _saveFileWithProgress(Stream<List<int>> stream, String filename, String? mimeType, int contentLength,
      void Function(int chunkLength) onProgress) async {
    final file = File('/path/to/save/$filename');
    final sink = file.openWrite();
    await for (final chunk in stream) {
      sink.add(chunk);
      onProgress(chunk.length); // 调用进度更新回调
    }
    await sink.close();
    return file;
  }
}
