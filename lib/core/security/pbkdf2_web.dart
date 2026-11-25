import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<List<int>?> derivePbkdf2Web(
  String password,
  List<int> salt,
  int iterations,
  int length,
) async {
  final subtle = web.window.crypto.subtle;
  final key = await subtle
      .importKey(
        'raw',
        Uint8List.fromList(utf8.encode(password)).toJS,
        'PBKDF2'.toJS,
        false,
        ['deriveBits'.toJS].toJS,
      )
      .toDart;
  final parameters = JSObject()
    ..['name'] = 'PBKDF2'.toJS
    ..['salt'] = Uint8List.fromList(salt).toJS
    ..['iterations'] = iterations.toJS
    ..['hash'] = 'SHA-256'.toJS;
  final bits = await subtle.deriveBits(parameters, key, length * 8).toDart;
  return bits.toDart.asUint8List();
}
