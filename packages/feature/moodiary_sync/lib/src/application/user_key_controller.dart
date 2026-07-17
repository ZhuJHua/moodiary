import 'dart:convert';

import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_key_controller.g.dart';

/// 同步数据密钥（DEK）的 Riverpod 视图 —— 只读；写入走 [SyncKeyManager]
/// （开启 / 改密码 / 关闭的编排在 user_key_change_flow），改完 invalidate 本 provider。
///
/// state 为 `null` 表示未开启加密；非空为 DEK 的 base64（供二维码跨设备传输）。
@riverpod
class SyncDekController extends _$SyncDekController {
  @override
  Future<String?> build() async {
    final dek = await SyncKeyManager.loadDek();
    return dek == null ? null : base64Encode(dek);
  }
}
