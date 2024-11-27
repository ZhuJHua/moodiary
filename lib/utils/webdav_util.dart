import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:mood_diary/utils/utils.dart';

class WebDavException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;

  WebDavException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    return 'WebDavException: $message, Cause: $cause';
  }
}

class WebDavUtil {
  late String baseUrl;
  late String username;
  late String password;
  late final Dio _dio;

  WebDavUtil() {
    var webDavOptions = Utils().prefUtil.getValue<List<String>>('webDavOption');
    if (webDavOptions == null || webDavOptions.isEmpty) {
      throw WebDavException("WebDAV options not configured");
    }
    baseUrl = webDavOptions[0];
    username = webDavOptions[1];
    password = webDavOptions[2];
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      },
      followRedirects: false,
    ));
  }

  Future<T> _safeExecute<T>(Future<T> Function() operation, String action) async {
    try {
      return await operation();
    } catch (e, stack) {
      throw WebDavException('Error during $action', cause: e, stackTrace: stack);
    }
  }

  Future<void> uploadFile(String remotePath, String localPath) async {
    await _safeExecute(() async {
      final file = await MultipartFile.fromFile(localPath);
      final formData = FormData.fromMap({'file': file});
      final response = await _dio.put(remotePath, data: formData);
      if (response.statusCode != StatusCode.CREATED && response.statusCode != StatusCode.NO_CONTENT) {
        throw Exception('Upload failed with status code: ${response.statusCode}');
      }
    }, 'uploadFile');
  }

  Future<void> downloadFile(String remotePath, String localPath) async {
    await _safeExecute(() async {
      final response = await _dio.download(remotePath, localPath);
      if (response.statusCode != StatusCode.OK) {
        throw Exception('Download failed with status code: ${response.statusCode}');
      }
    }, 'downloadFile');
  }

  Future<List<String>> listDirectory(String remotePath) async {
    return await _safeExecute(() async {
      final response = await _dio.request(
        remotePath,
        options: Options(method: 'PROPFIND', headers: {'Depth': '1'}),
      );
      if (response.statusCode == StatusCode.MULTI_STATUS) {
        return _parsePropFindResponse(response.data.toString());
      } else {
        throw Exception('Directory listing failed with status code: ${response.statusCode}');
      }
    }, 'listDirectory');
  }

  Future<void> deleteFile(String remotePath) async {
    await _safeExecute(() async {
      final response = await _dio.delete(remotePath);
      if (response.statusCode != StatusCode.NO_CONTENT) {
        throw Exception('Deletion failed with status code: ${response.statusCode}');
      }
    }, 'deleteFile');
  }

  Future<void> createDirectory(String remotePath) async {
    await _safeExecute(() async {
      final response = await _dio.request(
        remotePath,
        options: Options(method: 'MKCOL'),
      );
      if (response.statusCode != StatusCode.CREATED) {
        throw Exception('Directory creation failed with status code: ${response.statusCode}');
      }
    }, 'createDirectory');
  }

  Future<bool> exists(String remotePath) async {
    return await _safeExecute(() async {
      try {
        final response = await _dio.request(
          remotePath,
          options: Options(method: 'HEAD'),
        );
        return response.statusCode == StatusCode.OK;
      } on DioException catch (e) {
        if (e.response?.statusCode == StatusCode.NOT_FOUND) {
          return false;
        }
        rethrow;
      }
    }, 'exists');
  }

  List<String> _parsePropFindResponse(String xmlResponse) {
    final items = <String>[];
    final regex = RegExp(r'<D:href>(.*?)<\/D:href>');
    final matches = regex.allMatches(xmlResponse);
    for (var match in matches) {
      final href = match.group(1);
      if (href != null) {
        items.add(Uri.decodeFull(href));
      }
    }
    return items;
  }
}
