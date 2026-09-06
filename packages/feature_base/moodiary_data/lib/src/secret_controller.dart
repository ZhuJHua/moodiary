import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secret_controller.g.dart';

// SecureKV 没有通知机制：写完必须 ref.invalidate(secretKvProvider(key))，界面才会刷新
@riverpod
Future<String?> secretKv(Ref ref, MoodiarySecureKVs key) => key.get();
