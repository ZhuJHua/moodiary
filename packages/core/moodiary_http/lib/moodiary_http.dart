/// HTTP 端口与实现。请求走 Rust 的 reqwest，本地回环服务走 Rust 的 hyper；
/// 上层只认 [IHttpClient] / [IHttpServer] 两个端口。
library;

export 'src/http_client.dart';
export 'src/http_server.dart';
export 'src/impl/rust_http_client.dart';
export 'src/impl/rust_http_server.dart';
