import 'dart:convert';

import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_key_controller.g.dart';

@riverpod
class SyncDekController extends _$SyncDekController {
  @override
  Future<String?> build() async {
    final dek = await SyncKeyManager.loadDek();
    return dek == null ? null : base64Encode(dek);
  }
}
