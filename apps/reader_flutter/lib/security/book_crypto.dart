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
/// Honest limit: on a rooted/jailbroken device the legitimate logged-in user can
/// still dump plaintext from memory while a page renders — no client-side scheme
/// avoids that. This protects data at rest, which is the achievable guarantee.
class BookCrypto {
  BookCrypto._();

  static const _masterKeyName = 'vault_master_key_v1';
  static const _nonceLen = 12; // AES-GCM standard 96-bit nonce
  static const _macLen = 16; // 128-bit GCM tag

  static final AesGcm _algo = AesGcm.with256bits();
  static SecretKey? _cached;

  static Future<SecretKey> _masterKey() async {
    if (_cached != null) return _cached!;
    // The cryptography_flutter plugin auto-registers platform-native AES-GCM.
    final existing = await SecureKeyValue.read(_masterKeyName);
    if (existing != null && existing.isNotEmpty) {
      _cached = SecretKey(base64Decode(existing));
      return _cached!;
    }
    final key = await _algo.newSecretKey();
    final bytes = await key.extractBytes();
    await SecureKeyValue.write(_masterKeyName, base64Encode(bytes));
    _cached = SecretKey(bytes);
    return _cached!;
  }

  /// Seals [plain] into `nonce(12) || ciphertext || mac(16)`.
  static Future<Uint8List> seal(List<int> plain) async {
    final key = await _masterKey();
    final box = await _algo.encrypt(plain, secretKey: key);
    return Uint8List.fromList(
      [...box.nonce, ...box.cipherText, ...box.mac.bytes],
    );
  }

  /// Opens a blob produced by [seal]. Throws on tamper / wrong device key.
  static Future<Uint8List> open(Uint8List blob) async {
    final key = await _masterKey();
    if (blob.length < _nonceLen + _macLen) {
      throw const FormatException('vault blob too short');
    }
    final nonce = blob.sublist(0, _nonceLen);
    final cipher = blob.sublist(_nonceLen, blob.length - _macLen);
    final mac = blob.sublist(blob.length - _macLen);
    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final clear = await _algo.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }

  static Future<Uint8List> sealJson(Object json) async =>
      seal(utf8.encode(jsonEncode(json)));

  static Future<Map<String, dynamic>> openJson(Uint8List blob) async {
    final bytes = await open(blob);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  /// Wipe the master key (e.g. on logout). Makes every sealed book unreadable.
  static Future<void> wipeMasterKey() async {
    _cached = null;
    await SecureKeyValue.delete(_masterKeyName);
  }
}
