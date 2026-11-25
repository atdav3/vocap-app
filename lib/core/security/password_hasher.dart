import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'pbkdf2_stub.dart'
    if (dart.library.js_interop) 'pbkdf2_web.dart'
    as web_crypto;

/// PBKDF2-HMAC-SHA256 password storage with per-user 128-bit salt.
/// Work yields periodically so a slow browser does not monopolize its event loop.
class PasswordHasher {
  PasswordHasher._();

  static const _iterations = 120000;
  static const _bytes = 32;
  static final _random = Random.secure();

  static Future<String> hash(String password) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final derived = await _derive(password, salt, _iterations);
    return [
      'pbkdf2-sha256',
      '$_iterations',
      _hex(salt),
      _hex(derived),
    ].join(r'$');
  }

  static Future<bool> verify(String password, String encoded) async {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
    final iterations = int.tryParse(parts[1]);
    final salt = _unhex(parts[2]);
    final expected = _unhex(parts[3]);
    if (iterations == null ||
        iterations < 10000 ||
        iterations > 1000000 ||
        salt == null ||
        expected == null ||
        expected.length != _bytes) {
      return false;
    }
    final actual = await _derive(password, salt, iterations);
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ actual[i];
    }
    return difference == 0;
  }

  static Future<List<int>> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    final webDerived = await web_crypto.derivePbkdf2Web(
      password,
      salt,
      iterations,
      _bytes,
    );
    if (webDerived != null) return webDerived;

    final hmac = Hmac(sha256, utf8.encode(password));
    final input = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(input).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
      if (i % 1024 == 0) await Future<void>.delayed(Duration.zero);
    }
    return result.take(_bytes).toList(growable: false);
  }

  static String _hex(List<int> value) =>
      value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static List<int>? _unhex(String value) {
    if (value.length.isOdd || !RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      return null;
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ];
  }
}
