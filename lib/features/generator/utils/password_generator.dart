import 'dart:math';

class PasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  /// Generates a cryptographically secure random password.
  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
  }) {
    if (length < 8) length = 8;
    if (length > 64) length = 64;

    String chars = _lowercase;
    if (includeUppercase) chars += _uppercase;
    if (includeNumbers) chars += _numbers;
    if (includeSymbols) chars += _symbols;

    final random = Random.secure();
    final List<String> password = [];

    // Ensure at least one character of each selected type is included
    if (includeUppercase) {
      password.add(_uppercase[random.nextInt(_uppercase.length)]);
    }
    if (includeNumbers) {
      password.add(_numbers[random.nextInt(_numbers.length)]);
    }
    if (includeSymbols) {
      password.add(_symbols[random.nextInt(_symbols.length)]);
    }
    
    // Add lowercase (always included)
    password.add(_lowercase[random.nextInt(_lowercase.length)]);

    // Fill the rest
    while (password.length < length) {
      password.add(chars[random.nextInt(chars.length)]);
    }

    // Shuffle the result so the predictable characters aren't always first
    password.shuffle(random);

    return password.join('');
  }
}
