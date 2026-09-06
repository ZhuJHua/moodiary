import 'package:moodiary_storage/moodiary_storage.dart';

final class SecretKVMigration {
  SecretKVMigration._();

  static const Map<String, MoodiarySecureKVs> _moved = {
    'password': MoodiarySecureKVs.password,
    'qweatherKey': MoodiarySecureKVs.qweatherKey,
    'tiandituKey': MoodiarySecureKVs.tiandituKey,
  };

  static Set<String> get movedKeys => _moved.keys.toSet();

  static Future<void> run(IKVSource legacy) async {
    final lockWasOn = legacy.get<bool>('lock') == true;

    for (final MapEntry(key: name, value: target) in _moved.entries) {
      if (target == MoodiarySecureKVs.password && !lockWasOn) continue;
      final value = legacy.get<String>(name);
      if (value == null || value.isEmpty) continue;
      await target.set(value);
    }
  }
}
