pub mod api;
/// 导出 IR 的 Rust 镜像。放在 api/ 之外：它不跨桥，进 api/ 会被 FRB 扫到生成无用绑定。
mod export_ir;
mod frb_generated;
mod http_client;
