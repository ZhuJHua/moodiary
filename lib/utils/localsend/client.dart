import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mood_diary/utils/utils.dart';

class LocalLanClient {
  final dio = Utils().httpUtil.dio;
  final int port;
  RawDatagramSocket? socket;

  LocalLanClient({this.port = 4040});

  /// 初始化UDP套接字
  Future<void> initSocket() async {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    socket!.broadcastEnabled = true;
    print("UDP socket initialized on port $port");
  }

  /// 广播设备信息
  void broadcastPresence() {
    final message = utf8.encode("LocalLanClient: device here");
    socket!.send(message, InternetAddress("224.0.0.1"), port);
    print("Presence broadcasted");
  }

  /// 监听其他设备的广播消息
  void listenForDevices() {
    socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final packet = socket!.receive();
        if (packet != null) {
          final message = utf8.decode(packet.data);
          print("Discovered device at ${packet.address.address}: $message");
        }
      }
    });
  }

  /// 发送文件到指定设备IP
  Future<void> sendFile(String filePath, String deviceIp) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });

    try {
      final response = await dio.post(
        'http://$deviceIp:$port/upload',
        data: formData,
      );
      print("File sent successfully: ${response.data}");
    } catch (e) {
      print("Error sending file: $e");
    }
  }

  /// 关闭UDP套接字
  void closeSocket() {
    socket?.close();
    print("Socket closed");
  }
}
