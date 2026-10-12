import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Applies one `crypto.*` binding call from the sandbox (`docs/dev/book-source.md` §6).
///
/// The four operations are pure computation, which is why §6 lists them as **sync**
/// bindings: the worker answers them inside its own isolate and JavaScript never
/// waits for the UI isolate. [operation] is the name used on the JS side; the result
/// is the value JavaScript receives.
///
/// `null` means “no value”: an unknown operation, or base64 that cannot be decoded or
/// is not UTF-8 afterwards. The prelude turns that into a JS `Error` instead of a
/// silently wrong string, which is what C-SRC-4 asks for at a binding boundary.
String? applyCryptoOperation(String operation, String value) =>
    switch (operation) {
      'md5' => md5.convert(utf8.encode(value)).toString(),
      'sha1' => sha1.convert(utf8.encode(value)).toString(),
      'base64Encode' => base64Encode(utf8.encode(value)),
      'base64Decode' => _decodeBase64(value),
      _ => null,
    };

/// Decodes base64 to text, or `null` when the input is not valid base64 / UTF-8.
///
/// Upstream (`java`-backed `crypto.base64Decode`) throws on malformed input; here the
/// throw happens on the JS side (see [applyCryptoOperation]) so the engine behaviour
/// stays out of it.
String? _decodeBase64(String value) {
  try {
    return utf8.decode(base64Decode(value));
  } on FormatException {
    return null;
  }
}
