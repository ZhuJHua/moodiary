import 'dart:math';

class PasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _specialChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?/';

  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeNumbers = true,
    bool includeSpecialChars = true,
  }) {
    String chars = _lowercase;
    if (includeUppercase) chars += _uppercase;
    if (includeNumbers) chars += _numbers;
    if (includeSpecialChars) chars += _specialChars;

    final Random random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
