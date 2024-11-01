import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

class LocalLanServer {
  final int port;
  HttpServer? _server;

  LocalLanServer({this.port = 4040});

  /// 启动文件服务器
  Future<void> start() async {
    // 配置路由和中间件
    final handler = const Pipeline()
        .addMiddleware(logRequests()) // 日志中间件
        .addHandler(_router); // 路由处理器

    // 启动 Shelf 服务器
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print("Shelf server started on port $port");
  }

  /// 路由处理器
  Future<Response> _router(Request request) async {
    if (request.url.path == 'upload' && request.method == 'POST') {
      return _handleFileUpload(request);
    } else {
      return Response.notFound('Not Found');
    }
  }

  /// 处理文件上传请求
  Future<Response> _handleFileUpload(Request request) async {
    try {
      final multipart = request.multipart();
      await for (final part in multipart!.parts) {
        final fileName = 'received_${DateTime.now().millisecondsSinceEpoch}.file';
        final file = File('/path/to/save/$fileName'); // 替换为实际保存路径
        final sink = file.openWrite();
        await part.pipe(sink); // 将文件写入本地
        await sink.close();
        print("File received: ${file.path}");
      }
      return Response.ok('File received successfully');
    } catch (e) {
      print("Error receiving file: $e");
      return Response.internalServerError(body: 'File upload failed');
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    await _server?.close();
    print("Shelf server stopped");
  }
}
