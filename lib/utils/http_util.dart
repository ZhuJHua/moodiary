import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mood_diary/utils/utils.dart';

class HttpUtil {
  late final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));

  HttpUtil() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        return handler.next(options);
      },
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        return handler.next(response);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) {
        Utils().noticeUtil.showToast('网络异常！');
        return handler.next(error);
      },
    ));
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? parameters, ResponseType? type}) async {
    return await _dio.get<T>(path, queryParameters: parameters, options: Options(responseType: type));
  }

  Future<Response<T>> post<T>(String path, {Map<String, dynamic>? header, data, Options? option}) async {
    return await _dio.post<T>(path, options: Options(headers: header), data: data);
  }

  Future<Stream<String>?> postStream(String path, {Map<String, dynamic>? header, Object? data}) async {
    Response<ResponseBody> response =
        await _dio.post(path, options: Options(responseType: ResponseType.stream, headers: header), data: data);
    StreamTransformer<Uint8List, List<int>> transformer = StreamTransformer.fromHandlers(handleData: (data, sink) {
      sink.add(List<int>.from(data));
    });
    return response.data?.stream.transform(transformer).transform(const Utf8Decoder()).transform(const LineSplitter());
  }
}
