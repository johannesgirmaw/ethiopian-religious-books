import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_key_value.dart';

/// AES-256-GCM encryption-at-rest for downloaded books.
///
/// A single 256-bit device master key (the KEK) is generated on first use and
/// kept in the platform secure store (iOS Keychain / Android Keystore / desktop
/// keychain / Linux libsecret / Windows DPAPI). It never appears in any file we
/// write, so books copied off the device — backups, file managers, malware in
/// another app's sandbox — cannot be decrypted. Each blob is sealed with a fresh
/// random 96-bit nonce and a 128-bit GCM tag that authenticates it, so any
/// tampering makes [open] throw rather than return forged plaintext.
///
/// When [aadContext] is provided, blobs are written in format v1
/// (`FM\\x01 || nonce || ciphertext || mac`) with that UTF-8 string as GCM AAD
/// so ciphertext cannot be swapped across books/chunks. Legacy blobs (no
/// version magic) still open without AAD.
///
/// Honest limit: on a rooted/jailbroken device the legitimate logged-in user can
/// still dump plaintext from memory while a page renders — no client-side scheme
/// avoids that. This protects data at rest, which is the achievable guarantee.
class BookCrypto {
  BookCrypto._();

  static const _masterKeyName = 'vault_master_key_v1';
  static const _nonceLen = 12; // AES-GCM standard 96-bit nonce
  static const _macLen = 16; // 128-bit GCM tag

  /// Unambiguous v1 header (`FM` + version). Avoids colliding with a random
  /// GCM nonce byte (a single `0x01` prefix is ~1/256 of legacy blobs).
  static const _formatV1Magic = <int>[0x46, 0x4d, 0x01];

  /// Brief transitional single-byte marker from an earlier AAD rollout.
  static const _formatV1LegacyMarker = 0x01;

  /// Bytes added by [seal] without AAD: nonce plus GCM tag.
  /// Chunked PDF storage uses this for legacy-sized pieces; v1 adds magic.
  static const sealedOverhead = _nonceLen + _macLen;

  /// Extra bytes when sealing with [aadContext] (format v1 magic).
  static const sealedOverheadV1 = 3 + sealedOverhead;

  static final AesGcm _algo = AesGcm.with256bits();
  static SecretKey? _cached;

  static const _keyBytes = 32; // AES-256

  static Future<SecretKey> _masterKey() async {
    if (_cached != null) return _cached!;
    // The cryptography_flutter plugin auto-registers platform-native AES-GCM.
    final existing = await SecureKeyValue.read(_masterKeyName);
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = base64Decode(existing);
        if (decoded.length == _keyBytes) {
          _cached = SecretKey(decoded);
          return _cached!;
        }
      } catch (_) {
        // Corrupt encoding — fall through and rotate.
      }
      // Wrong length / corrupt material must not be used as an AES key.
      await SecureKeyValue.delete(_masterKeyName);
    }
    final key = await _algo.newSecretKey();
    final bytes = await key.extractBytes();
    if (bytes.length != _keyBytes) {
      throw StateError('AES-256 master key must be $_keyBytes bytes');
    }
    await SecureKeyValue.write(_masterKeyName, base64Encode(bytes));
    _cached = SecretKey(bytes);
    return _cached!;
  }

  static List<int>? _aadBytes(String? aadContext) {
    if (aadContext == null || aadContext.isEmpty) return null;
    return utf8.encode(aadContext);
  }

  /// Seals [plain] into `nonce(12) || ciphertext || mac(16)`, or when
  /// [aadContext] is set: `FM\\x01 || nonce || ciphertext || mac` with AAD.
  static Future<Uint8List> seal(List<int> plain, {String? aadContext}) async {
    final key = await _masterKey();
    final aad = _aadBytes(aadContext);
    final SecretBox box;
    if (aad == null) {
      box = await _algo.encrypt(plain, secretKey: key);
    } else {
      box = await _algo.encrypt(plain, secretKey: key, aad: aad);
    }
    final body = <int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];
    if (aad == null) return Uint8List.fromList(body);
    return Uint8List.fromList([..._formatV1Magic, ...body]);
  }

  static bool _hasMagic(Uint8List blob, List<int> magic) {
    if (blob.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (blob[i] != magic[i]) return false;
    }
    return true;
  }

  /// Opens a blob produced by [seal]. Throws on tamper / wrong device key /
  /// wrong AAD. Legacy blobs (no version magic) open without AAD even if
  /// [aadContext] is passed, so upgrades stay readable.
  ///
  /// Also accepts the brief single-byte `0x01` marker; a legacy nonce can
  /// start with that value (~1/256), so that path falls back to legacy on
  /// decrypt failure.
  static Future<Uint8List> open(Uint8List blob, {String? aadContext}) async {
    final key = await _masterKey();
    final aad = _aadBytes(aadContext);
    if (aad != null && _hasMagic(blob, _formatV1Magic)) {
      return _openBody(
        key,
        blob.sublist(_formatV1Magic.length),
        aad: aad,
      );
    }
    if (aad != null &&
        blob.isNotEmpty &&
        blob[0] == _formatV1LegacyMarker) {
      try {
        return await _openBody(key, blob.sublist(1), aad: aad);
      } catch (_) {
        // Likely a legacy blob whose random nonce starts with 0x01.
      }
    }
    return _openBody(key, blob, aad: null);
  }

  static Future<Uint8List> _openBody(
    SecretKey key,
    Uint8List body, {
    required List<int>? aad,
  }) async {
    if (body.length < _nonceLen + _macLen) {
      throw const FormatException('vault blob too short');
    }
    final nonce = body.sublist(0, _nonceLen);
    final cipher = body.sublist(_nonceLen, body.length - _macLen);
    final mac = body.sublist(body.length - _macLen);
    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final List<int> clear;
    if (aad == null) {
      clear = await _algo.decrypt(box, secretKey: key);
    } else {
      clear = await _algo.decrypt(box, secretKey: key, aad: aad);
    }
    return Uint8List.fromList(clear);
  }

  static Future<Uint8List> sealJson(Object json, {String? aadContext}) async =>
      seal(utf8.encode(jsonEncode(json)), aadContext: aadContext);

  static Future<Map<String, dynamic>> openJson(
    Uint8List blob, {
    String? aadContext,
  }) async {
    final bytes = await open(blob, aadContext: aadContext);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  /// Wipe the master key (e.g. on logout). Makes every sealed book unreadable.
  static Future<void> wipeMasterKey() async {
    _cached = null;
    await SecureKeyValue.delete(_masterKeyName);
  }
}
