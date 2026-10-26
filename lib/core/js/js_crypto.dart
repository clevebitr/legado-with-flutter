/// The **byte-level** half of upstream's `JsEncodeUtils` (M25/S3a, `docs/dev/book-source.md` §6).
///
/// Upstream reaches this family through Rhino: `java.hexDecodeToByteArray(…)` answers a real Java
/// `byte[]`, and `java.createSymmetricCrypto(…)` answers a live `SymmetricCryptoAndroid` object.
/// A QuickJS isolate has neither, so this file defines the two shapes the sandbox emulates:
///
/// * **`byte[]` → a JS `Uint8Array`.** It answers `length`, `[i]`, `Array.from(…)` and `slice(…)`,
///   which is exactly how the corpus uses it (`Array.from(body).slice(8, -16)`), and it crosses the
///   isolate boundary as one typed array instead of a JSON array of numbers.
/// * **`SymmetricCrypto` → an opaque `{__symmetric: true, id}` handle.** The cipher never enters the
///   script: every method call travels back here with the handle id, the same contract the font
///   registry uses for fonts (`ADR-0068` §决策 9).
///
/// The cipher itself runs on `pointycastle` (MIT, pure Dart). Java's transformation strings are
/// normalised the way `SymmetricCryptoAndroid` normalises them, including its key truncation for
/// DES / DESede.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_reader/core/js/js_bindings.dart'
    show applyCryptoOperation;
import 'package:flutter_reader/core/text/charset_encoding.dart';
import 'package:pointycastle/api.dart'
    show
        BlockCipher,
        CipherParameters,
        KeyParameter,
        PaddedBlockCipherParameters,
        ParametersWithIV;
import 'package:pointycastle/block/aes.dart' show AESEngine;
import 'package:pointycastle/block/desede_engine.dart' show DESedeEngine;
import 'package:pointycastle/block/modes/cbc.dart' show CBCBlockCipher;
import 'package:pointycastle/block/modes/ecb.dart' show ECBBlockCipher;
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart'
    show PaddedBlockCipherImpl;
import 'package:pointycastle/paddings/pkcs7.dart' show PKCS7Padding;

/// The key an envelope uses to report a failure the rule can read.
///
/// The sandbox checks for it before it looks at the answer, so every `java.*` byte call that cannot
/// be answered fails as a readable `Error` instead of `undefined is not a function`.
const String jsCryptoErrorKey = '__error';

/// Applies one call of the sandbox's byte / cipher family, answering what the JS side expects.
///
/// Returns a [String] for text results, a [Uint8List] for `byte[]` results (the plugin hands JS a
/// `Uint8Array`), `null` when a verb genuinely has no answer (`base64DecodeToByteArray('')`) and
/// `{jsCryptoErrorKey: message}` when the *call* is wrong — an unknown transformation, a bad key
/// length, a missing IV. The last one becomes a JS `Error` carrying `message`, which is the only way
/// a rule (or the person debugging the rule) learns what went wrong.
///
/// `args` is the JSON-shaped payload the worker built: `{operation, value, …}`. The four verbs the
/// sandbox has always had (`md5` / `sha1` / `base64Encode` / `base64Decode`) delegate to
/// [applyCryptoOperation] so there is exactly one decoder for them.
Object? applyJsCryptoCall(Object? args, {JsSymmetricRegistry? ciphers}) {
  if (args is! Map) {
    return _failure('malformed crypto call');
  }
  final Object? operation = args['operation'];
  if (operation is! String || operation.isEmpty) {
    return _failure('malformed crypto call');
  }
  // 上游这一族全是同步的纯计算，一次都不该离开 worker；参数错了就当场说清楚是哪一条。
  try {
    switch (operation) {
      case 'md5':
      case 'sha1':
      case 'base64Encode':
      case 'base64Decode':
        return applyCryptoOperation(operation, _requiredText(args['value']));
      case 'md5Encode16':
        return _md5Encode16(_requiredText(args['value']));
      case 'base64DecodeToByteArray':
        return decodeLooseBase64(_requiredText(args['value']));
      case 'hexDecodeToByteArray':
        return decodeHexBytes(_requiredText(args['value']));
      case 'hexEncodeToString':
        return encodeHexBytes(utf8.encode(_requiredText(args['value'])));
      case 'hexDecodeToString':
        return charsetText(
          decodeHexBytes(_requiredText(args['value'])),
          charset: 'UTF-8',
        );
      case 'strToBytes':
        return Uint8List.fromList(
          charsetBytes(_requiredText(args['value']), charset: _charsetOf(args)),
        );
      case 'bytesToStr':
        return charsetText(
          _requiredBytes(args['value']),
          charset: _charsetOf(args),
        );
      case 'digestHex':
        return _hashOf(_requiredText(args['algorithm']))
            .convert(utf8.encode(_requiredText(args['value'])))
            .toString();
      case 'digestBase64Str':
        return base64Encode(
          _hashOf(_requiredText(args['algorithm']))
              .convert(utf8.encode(_requiredText(args['value'])))
              .bytes,
        );
      case 'HMacHex':
        return _hmac(args).toString();
      case 'HMacBase64':
        return base64Encode(_hmac(args).bytes);
      case 'symmetricCreate':
        return _createCipher(args, ciphers);
      case 'symmetricCall':
        return _callCipher(args, ciphers);
      default:
        return _failure('java.$operation is not a crypto binding');
    }
  } on FormatException catch (error) {
    return _failure(error.message);
  }
}

/// The flag that marks a sandbox object as a symmetric-cipher handle (`{__symmetric: true, id}`).
const String jsSymmetricHandleFlag = '__symmetric';

/// Decodes base64 the way upstream's `String.base64ToByteArray()` does (hutool's tolerant decoder).
///
/// Whitespace is dropped, the url-safe alphabet is accepted and missing padding is added, so a
/// key lifted out of a URL still decodes. `null` for blank input (upstream answers `null` there too)
/// or for text that is not base64 at all.
Uint8List? decodeLooseBase64(String value, {int? flags}) {
  // `flags` 是 Android `Base64` 的那套位掩码：上游两个 `base64DecodeToByteArray` 重载都只是把它
  // 转给 hutool 的宽容解码器，所以这里接受签名、按宽容规则解，不按位分支。
  final String text = value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  if (text.isEmpty) {
    return null;
  }
  final int remainder = text.length % 4;
  if (remainder == 1) {
    // 4n+1 个字符不可能是 base64：补齐也没用，直接答「解不了」。
    return null;
  }
  final String padded = remainder == 0
      ? text
      : text.padRight(text.length + (4 - remainder), '=');
  try {
    return base64Decode(padded);
  } on FormatException {
    return null;
  }
}

/// Decodes a hex string into bytes, throwing [FormatException] when it is not hex.
///
/// Upstream `String.hexToByteArray()` requires an even number of characters and rejects anything
/// outside `0-9a-fA-F`; the message here names the offence so a broken rule is debuggable.
Uint8List decodeHexBytes(String value) {
  final String text = value.replaceAll(RegExp(r'\s+'), '');
  if (text.length.isOdd) {
    throw const FormatException(
      'hex input must have an even number of characters',
    );
  }
  final Uint8List bytes = Uint8List(text.length ~/ 2);
  for (int index = 0; index < bytes.length; index++) {
    final int high = _hexDigit(text.codeUnitAt(index * 2));
    final int low = _hexDigit(text.codeUnitAt(index * 2 + 1));
    bytes[index] = (high << 4) | low;
  }

  return bytes;
}

/// Encodes [bytes] as lowercase hex, upstream's `ByteArray.toHexString()`.
String encodeHexBytes(Iterable<int> bytes) {
  final StringBuffer buffer = StringBuffer();
  for (final int byte in bytes) {
    buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0'));
  }

  return buffer.toString();
}

/// Whether [value] is entirely hex, upstream's `String.isHex()` (empty counts as hex there too).
bool isHexText(String value) => value.codeUnits.every((int unit) {
  return (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x46) ||
      (unit >= 0x61 && unit <= 0x66);
});

/// One `java.createSymmetricCrypto(…)` handle: a transformation plus a key and an optional IV.
///
/// Mirrors `SymmetricCryptoAndroid`: a bare algorithm means `/ECB/PKCS5Padding`, DES keys longer than
/// 8 bytes are truncated to 8 and DESede keys longer than 24 to 24, and a `null` key means a random
/// one. Only `ECB` and `CBC` modes are supported (`book-source.md` §11 records the rest).
final class JsSymmetricCrypto {
  /// Parses [transformation] and normalises the key, throwing [FormatException] when either is
  /// unusable — the sandbox turns that into a readable JS error.
  factory JsSymmetricCrypto({
    required String transformation,
    Uint8List? key,
    Uint8List? iv,
  }) {
    final _Transformation parsed = _Transformation.parse(transformation);

    return JsSymmetricCrypto._(parsed, _normaliseKey(parsed, key), iv);
  }

  JsSymmetricCrypto._(this._parsed, this._key, this._iv);

  final _Transformation _parsed;
  final Uint8List _key;
  Uint8List? _iv;

  /// The transformation as it will be applied, e.g. `AES/CBC/PKCS5Padding`.
  String get transformation => _parsed.name;

  /// `java.createSymmetricCrypto(…).setIv(bytes)`, answering `this` like the Java object does.
  JsSymmetricCrypto setIv(Uint8List? iv) {
    _iv = iv;

    return this;
  }

  /// Encrypts [data]; the answer is the raw ciphertext (upstream's `encrypt`).
  Uint8List encrypt(Uint8List data) => _run(forEncryption: true, data: data);

  /// Decrypts [data]; the answer is the raw plaintext (upstream's `decrypt`).
  Uint8List decrypt(Uint8List data) => _run(forEncryption: false, data: data);

  Uint8List _run({required bool forEncryption, required Uint8List data}) {
    final BlockCipher mode = _modeCipher();
    final CipherParameters parameters = _parameters();
    if (_parsed.padding == _CipherPadding.none) {
      final int blockSize = mode.blockSize;
      if (data.isEmpty || data.length % blockSize != 0) {
        // NoPadding 的字节数必须正好是整数块：Java 会抛 IllegalBlockSizeException，本仓同样失败，
        // 而不是悄悄补零（补零会让规则拿到「解出来但尾部是垃圾」的值）。
        throw FormatException(
          'NoPadding input must be a non-zero multiple of $blockSize bytes '
          '(got ${data.length})',
        );
      }
      mode.init(forEncryption, parameters);
      final Uint8List out = Uint8List(data.length);
      for (int offset = 0; offset < data.length; offset += blockSize) {
        mode.processBlock(data, offset, out, offset);
      }

      return out;
    }
    final PaddedBlockCipherImpl cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), mode)..init(
          forEncryption,
          PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
            parameters,
            null,
          ),
        );

    return cipher.process(data);
  }

  // Java 的 `PKCS5Padding` 在 AES（16 字节块）上就是 PKCS7，pointycastle 只有后者，所以两者同路。
  BlockCipher _modeCipher() {
    final BlockCipher engine = switch (_parsed.kind) {
      _EngineKind.aes => AESEngine(),
      // pointycastle 4 只带三倍 DES 引擎；单 DES 就是 K1 = K2 = K3 的 DESede
      // （_normaliseKey 已经把 8 字节密钥复制成三份）。
      _EngineKind.des || _EngineKind.desede => DESedeEngine(),
    };

    return switch (_parsed.mode) {
      _CipherMode.ecb => ECBBlockCipher(engine),
      _CipherMode.cbc => CBCBlockCipher(engine),
    };
  }

  CipherParameters _parameters() {
    if (_parsed.mode == _CipherMode.ecb) {
      // ECB 没有 IV：上游在 `transformation.contains("/ECB/")` 时直接 `init(mode, key)`。
      return KeyParameter(_key);
    }
    final Uint8List? iv = _iv;
    if (iv == null || iv.isEmpty) {
      throw FormatException('${_parsed.name} needs an iv');
    }

    return ParametersWithIV(KeyParameter(_key), iv);
  }

  static Uint8List _normaliseKey(_Transformation parsed, Uint8List? key) {
    final int size = key?.length ?? 0;
    switch (parsed.kind) {
      case _EngineKind.aes:
        if (key == null) {
          return _randomKey(32);
        }
        if (size == 16 || size == 24 || size == 32) {
          return key;
        }

        throw FormatException('AES key must be 16, 24 or 32 bytes (got $size)');
      case _EngineKind.des:
        final Uint8List base = key == null
            ? _randomKey(8)
            : (size > 8 ? Uint8List.sublistView(key, 0, 8) : key);
        if (base.length != 8) {
          throw FormatException('DES key must be 8 bytes (got ${base.length})');
        }
        // K1 = K2 = K3 的 DESede 就是单 DES（见 _modeCipher）。
        final Uint8List repeated = Uint8List(24);
        for (int round = 0; round < 3; round++) {
          repeated.setRange(round * 8, round * 8 + 8, base);
        }

        return repeated;
      case _EngineKind.desede:
        if (key == null) {
          return _randomKey(24);
        }
        if (size > 24) {
          return Uint8List.sublistView(key, 0, 24);
        }
        if (size == 16 || size == 24) {
          return key;
        }

        throw FormatException('DESede key must be 16 or 24 bytes (got $size)');
    }
  }

  static Uint8List _randomKey(int length) {
    // 上游在 key 为 null 时用 KeyGenerator 生成随机密钥；规则只可能在同一段脚本里加密再解密，
    // 所以随机源不需要可复现，但不能用可预测的种子。
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

/// The symmetric ciphers one JS job created, keyed by the handle its sandbox object carries.
///
/// Scoped like the font registry: the worker clears it when a job starts and ids are never reused, so
/// a handle a script stashed in `globalThis` answers "unknown handle" instead of another source's
/// cipher.
final class JsSymmetricRegistry {
  /// Creates a registry holding at most [maxCiphers] ciphers; the oldest is dropped first.
  JsSymmetricRegistry({this.maxCiphers = 8});

  /// How many handles stay live at once.
  final int maxCiphers;

  final Map<int, JsSymmetricCrypto> _ciphers = <int, JsSymmetricCrypto>{};
  int _nextId = 1;

  /// How many handles are currently live.
  int get length => _ciphers.length;

  /// Registers [cipher] and answers the handle id the sandbox will carry.
  int add(JsSymmetricCrypto cipher) {
    while (_ciphers.length >= maxCiphers) {
      _ciphers.remove(_ciphers.keys.first);
    }
    final int id = _nextId++;
    _ciphers[id] = cipher;

    return id;
  }

  /// The cipher a handle refers to, or `null` when it is not a live handle.
  JsSymmetricCrypto? resolve(Object? handle) =>
      handle is int ? _ciphers[handle] : null;

  /// Forgets every cipher; called when a job starts.
  void clear() => _ciphers.clear();
}

// 一条 `java.*` 字节调用的全部动词里，只有 create / call 需要句柄表；其余都是纯函数。
Object? _createCipher(
  Map<Object?, Object?> args,
  JsSymmetricRegistry? ciphers,
) {
  if (ciphers == null) {
    throw const FormatException(
      'java.createSymmetricCrypto is unavailable here',
    );
  }
  final JsSymmetricCrypto cipher = JsSymmetricCrypto(
    transformation: _requiredText(args['transformation']),
    key: _optionalKeyBytes(args['key']),
    iv: _optionalKeyBytes(args['iv']),
  );

  return <String, Object?>{
    jsSymmetricHandleFlag: true,
    'id': ciphers.add(cipher),
  };
}

Object? _callCipher(Map<Object?, Object?> args, JsSymmetricRegistry? ciphers) {
  final JsSymmetricCrypto? cipher = ciphers?.resolve(args['id']);
  if (cipher == null) {
    // 句柄过期（跨 job）或伪造，两者都只能报「不认识」，绝不能回落到别的密码器。
    throw const FormatException('unknown symmetric crypto handle');
  }
  final String method = _requiredText(args['method']);
  final Object? value = args['value'];
  final String? charset = args['charset'] is String
      ? args['charset'] as String
      : null;
  switch (method) {
    case 'setIv':
      cipher.setIv(_optionalKeyBytes(value));

      return true;
    case 'encrypt':
      return cipher.encrypt(_operandBytes(value, charset));
    case 'encryptBase64':
      return base64Encode(cipher.encrypt(_operandBytes(value, charset)));
    case 'encryptHex':
      return encodeHexBytes(cipher.encrypt(_operandBytes(value, charset)));
    case 'encryptStr':
      return _textOfBytes(cipher.encrypt(_operandBytes(value, charset)));
    case 'decrypt':
      return cipher.decrypt(_decryptOperand(value));
    case 'decryptStr':
      return _textOfBytes(cipher.decrypt(_decryptOperand(value)));
    case 'decryptHex':
      return cipher.decrypt(decodeHexBytes(_requiredText(value)));
    case 'decryptBase64':
      return cipher.decrypt(_requiredBase64(_requiredText(value)));
    default:
      throw FormatException('unknown symmetric crypto method: $method');
  }
}

// 上游 `decrypt(data: String)` 先猜编码：全 hex 且长度为偶数按 hex，否则按 base64
// （`SymmetricCryptoAndroid.kt:80-90`）。字节数组（`Uint8Array`）则是原样密文。
Uint8List _decryptOperand(Object? value) {
  if (value is! String) {
    return _optionalBytes(value) ??
        (throw const FormatException('decrypt expects text or bytes'));
  }
  if (isHexText(value) && value.length.isEven && value.isNotEmpty) {
    return decodeHexBytes(value);
  }

  return _requiredBase64(value);
}

// 文本操作数一律 UTF-8（上游 `data.toByteArray()`），`charset` 只在加密侧的重载里出现。
Uint8List _operandBytes(Object? value, String? charset) {
  if (value is String) {
    return Uint8List.fromList(charsetBytes(value, charset: charset));
  }

  return _optionalBytes(value) ??
      (throw const FormatException('expected text or bytes'));
}

String _textOfBytes(Uint8List bytes) =>
    utf8.decode(bytes, allowMalformed: true);

String? _charsetOf(Map<Object?, Object?> args) => switch (args['charset']) {
  final String charset => charset,
  _ => null,
};

Uint8List _requiredBase64(String value) {
  final Uint8List? bytes = decodeLooseBase64(value);
  if (bytes == null) {
    throw const FormatException('input is neither hex nor base64');
  }

  return bytes;
}

String _md5Encode16(String value) {
  // 上游 `MD5Utils.md5Encode16`：取 32 位摘要的第 9..24 位字符。
  return crypto.md5.convert(utf8.encode(value)).toString().substring(8, 24);
}

crypto.Hash _hashOf(String algorithm) {
  final String name = algorithm.trim().toUpperCase().replaceAll(
    RegExp('[-_ ]'),
    '',
  );

  return switch (name) {
    'MD5' => crypto.md5,
    'SHA1' => crypto.sha1,
    'SHA224' => crypto.sha224,
    'SHA256' => crypto.sha256,
    'SHA384' => crypto.sha384,
    'SHA512' => crypto.sha512,
    _ => throw FormatException('unsupported digest algorithm: $algorithm'),
  };
}

crypto.Digest _hmac(Map<Object?, Object?> args) {
  // Java 的 Mac 算法名带前缀（`HmacSHA256` / `HmacSHA1` / `HMAC-SHA1`），摘要本身的名字没带。
  final String algorithm = _requiredText(args['algorithm'])
      .trim()
      .toUpperCase()
      .replaceAll(RegExp('[-_ ]'), '');
  final String digestName = algorithm.startsWith('HMAC')
      ? algorithm.substring(4)
      : algorithm;
  final crypto.Hash hash = _hashOf(digestName);
  final List<int> key = utf8.encode(_requiredText(args['key']));

  return crypto.Hmac(
    hash,
    key,
  ).convert(utf8.encode(_requiredText(args['value'])));
}

String _requiredText(Object? value) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    // `String(undefined)` 在脚本里是 "undefined"，这里不替它猜，直接说参数不对。
    throw const FormatException('expected text');
  }

  return value.toString();
}

// 字节操作数：JS 侧的 `Uint8Array` 过桥就是 Uint8List；普通数组（`Array.from(bytes)` 的结果）
// 也会走这条兜底，元素越界即报错，而不是按位截断静默改值。
// 密钥 / IV 操作数：字符串按 UTF-8 取字节（上游 `String.encodeToByteArray()`），字节数组原样。
Uint8List? _optionalKeyBytes(Object? value) {
  if (value is String) {
    return Uint8List.fromList(utf8.encode(value));
  }

  return _optionalBytes(value);
}

Uint8List _requiredBytes(Object? value) =>
    _optionalBytes(value) ??
    (throw const FormatException('expected a byte array'));

Uint8List? _optionalBytes(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Uint8List) {
    return value;
  }
  if (value is List) {
    final Uint8List bytes = Uint8List(value.length);
    for (int index = 0; index < value.length; index++) {
      final Object? element = value[index];
      if (element is! int || element < 0 || element > 255) {
        throw const FormatException('byte array elements must be 0..255');
      }
      bytes[index] = element;
    }

    return bytes;
  }
  throw const FormatException('expected bytes');
}

Map<String, Object?> _failure(String message) => <String, Object?>{
  jsCryptoErrorKey: message,
};

int _hexDigit(int unit) {
  if (unit >= 0x30 && unit <= 0x39) {
    return unit - 0x30;
  }
  if (unit >= 0x41 && unit <= 0x46) {
    return unit - 0x41 + 10;
  }
  if (unit >= 0x61 && unit <= 0x66) {
    return unit - 0x61 + 10;
  }
  throw const FormatException('hex input contains a non-hex character');
}

enum _EngineKind { aes, des, desede }

enum _CipherMode { ecb, cbc }

enum _CipherPadding { pkcs7, none }

/// One parsed Java transformation string (`ALG/MODE/PADDING`, mode and padding optional).
final class _Transformation {
  const _Transformation(this.name, this.kind, this.mode, this.padding);

  factory _Transformation.parse(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'createSymmetricCrypto: transformation is empty',
      );
    }
    // 上游：`if (algorithm.contains('/')) algorithm else "$algorithm/ECB/PKCS5Padding"`。
    final String name = trimmed.contains('/')
        ? trimmed
        : '$trimmed/ECB/PKCS5Padding';
    final List<String> parts = name.split('/');
    if (parts.length != 3) {
      throw FormatException('unsupported transformation: $raw');
    }
    final String algorithm = parts[0].trim().toUpperCase();
    final String mode = parts[1].trim().toUpperCase();
    final String padding = parts[2].trim().toUpperCase();
    final _EngineKind kind = switch (algorithm) {
      'AES' => _EngineKind.aes,
      'DES' => _EngineKind.des,
      'DESEDE' || 'TRIPLEDES' || '3DES' => _EngineKind.desede,
      _ => throw FormatException(
        'unsupported algorithm "$parts[0]": only AES, DES and DESede are bound '
        'to the sandbox (book-source.md §11)',
      ),
    };
    final _CipherMode cipherMode = switch (mode) {
      'ECB' => _CipherMode.ecb,
      'CBC' => _CipherMode.cbc,
      _ => throw FormatException(
        'unsupported mode "$parts[1]": only ECB and CBC are bound to the sandbox '
        '(book-source.md §11)',
      ),
    };
    final _CipherPadding cipherPadding = switch (padding) {
      // Java 的 PKCS5Padding 只对 8 字节块才有「5」的意思；对 AES 它与 PKCS7 逐字节相同，
      // 所以两者同路（上游 Android 的 provider 也是这么实现的）。
      'PKCS5PADDING' || 'PKCS7PADDING' => _CipherPadding.pkcs7,
      'NOPADDING' => _CipherPadding.none,
      _ => throw FormatException(
        'unsupported padding "$parts[2]": only PKCS5/PKCS7 and NoPadding are '
        'bound to the sandbox (book-source.md §11)',
      ),
    };

    return _Transformation(name, kind, cipherMode, cipherPadding);
  }

  final String name;
  final _EngineKind kind;
  final _CipherMode mode;
  final _CipherPadding padding;
}
