import 'package:clock/clock.dart';
import 'package:fast_crypto/fast_crypto.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

sealed class PinAttempt {
  const PinAttempt();
}

final class PinAccepted extends PinAttempt {
  const PinAccepted();
}

final class PinRejected extends PinAttempt {
  final int remaining;
  const PinRejected(this.remaining);
}

final class PinLockedOut extends PinAttempt {
  final Duration left;
  const PinLockedOut(this.left);
}

final class AppLockPin {
  AppLockPin._();

  static const int maxAttempts = 5;
  static const Duration cooldown = Duration(seconds: 30);

  @visibleForTesting
  static Future<String> Function(String pin) hasher = _rustHash;
  @visibleForTesting
  static Future<bool> Function(String hash, String pin) verifier = _rustVerify;

  static Future<String> _rustHash(String pin) => Argon2.hash(password: pin);

  static Future<bool> _rustVerify(String hash, String pin) =>
      Argon2.verify(hash: hash, password: pin);

  static bool isHashed(String stored) => stored.startsWith(r'$argon2');

  static final ValueNotifier<bool> _enabled = ValueNotifier(false);

  static ValueListenable<bool> get enabled => _enabled;

  static Future<void> load() async {
    if (MoodiaryKVs.appLockHint.get() == false) {
      _enabled.value = false;
      return;
    }
    final String? stored;
    try {
      stored = await MoodiarySecureKVs.password.get();
    } catch (e, s) {
      logger.e('应用锁：凭据读取失败，按未开启处理', error: e, stackTrace: s);
      _enabled.value = false;
      return;
    }
    final on = stored != null && stored.isNotEmpty;
    MoodiaryKVs.appLockHint.set(on);
    _enabled.value = on;
  }

  static Future<void> set(String pin) async {
    await MoodiarySecureKVs.password.set(await hasher(pin));
    MoodiaryKVs.appLockHint.set(true);
    _enabled.value = true;
  }

  static Future<void> clear() async {
    resetAttempts();
    MoodiaryKVs.appLockHint.set(false);
    await MoodiarySecureKVs.password.remove();
    _enabled.value = false;
  }

  static Future<String?> _read() async {
    try {
      return await MoodiarySecureKVs.password.get();
    } catch (e, s) {
      logger.e('应用锁：凭据读取失败，按未开启处理', error: e, stackTrace: s);
      return null;
    }
  }

  static Future<bool> verify(String pin) async {
    try {
      final stored = await _read();
      if (stored == null || stored.isEmpty) return false;
      if (!isHashed(stored)) {
        if (stored != pin) return false;
        await set(pin);
        return true;
      }
      return await verifier(stored, pin);
    } catch (e, s) {
      logger.e('应用锁：校验 PIN 失败', error: e, stackTrace: s);
      return false;
    }
  }

  static Duration lockoutLeft() {
    final now = clock.now();
    final until = MoodiaryKVs.appLockLockedUntil.get() ?? 0;
    final left = Duration(milliseconds: until - now.millisecondsSinceEpoch);
    if (left <= Duration.zero) return Duration.zero;
    if (left <= cooldown) return left;
    MoodiaryKVs.appLockLockedUntil.set(
      now.add(cooldown).millisecondsSinceEpoch,
    );
    return cooldown;
  }

  static void resetAttempts() {
    MoodiaryKVs.appLockFailCount.set(0);
    MoodiaryKVs.appLockLockedUntil.set(0);
  }

  static Future<PinAttempt> attempt(String pin) async {
    final left = lockoutLeft();
    if (left > Duration.zero) return PinLockedOut(left);
    if (await verify(pin)) {
      resetAttempts();
      return const PinAccepted();
    }
    final failed = (MoodiaryKVs.appLockFailCount.get() ?? 0) + 1;
    if (failed < maxAttempts) {
      MoodiaryKVs.appLockFailCount.set(failed);
      return PinRejected(maxAttempts - failed);
    }
    MoodiaryKVs.appLockFailCount.set(0);
    MoodiaryKVs.appLockLockedUntil.set(
      clock.now().add(cooldown).millisecondsSinceEpoch,
    );
    return const PinLockedOut(cooldown);
  }
}
