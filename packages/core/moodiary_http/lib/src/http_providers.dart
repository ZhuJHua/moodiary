import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'http_client.dart';
import 'http_server.dart';
import 'impl/rust_http_server.dart';

part 'http_providers.g.dart';

@Riverpod(keepAlive: true)
IHttpClient httpClient(Ref ref) =>
    throw UnimplementedError('httpClientProvider must be overridden');

typedef HttpServerFactory = IHttpServer Function();

@Riverpod(keepAlive: true)
HttpServerFactory httpServerFactory(Ref ref) => RustHttpServer.new;
