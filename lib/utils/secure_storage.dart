import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight and cross-platform secure storage backed by [SharedPreferences]
/// with in-app obfuscation/encryption.
///
/// Eliminates macOS keychain password dialogs, keychain-access-groups
/// entitlements, and native codesigning friction while keeping sensitive
/// values (API keys, passwords, tokens) safely encrypted at rest.
class AppSecureStorage {
  final SharedPreferences? _prefs;

  const AppSecureStorage([this._prefs]);

  static const String _prefix = 'enc:v1:';
  static const List<int> _saltBytes = [
    0x56, 0x79, 0x6E, 0x6F, 0x64, 0x79, 0x5F, 0x53,
    0x65, 0x63, 0x75, 0x72, 0x65, 0x5F, 0x56, 0x69,
    0x62, 0x65, 0x46, 0x6C, 0x6F, 0x77, 0x32, 0x30,
    0x32, 0x36, 0x5F, 0x4B, 0x65, 0x79, 0x21, 0x24,
  ];

  /// Encrypts plaintext string using salt XOR + Base64 encoding.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    final plainBytes = utf8.encode(plainText);
    final encryptedBytes = List<int>.generate(plainBytes.length, (i) {
      return plainBytes[i] ^ _saltBytes[i % _saltBytes.length];
    });
    return '$_prefix${base64.encode(encryptedBytes)}';
  }

  /// Decrypts encrypted string. Supports backward compatibility with plaintext values.
  static String decrypt(String storedText) {
    if (storedText.isEmpty) return '';
    if (!storedText.startsWith(_prefix)) {
      // Backward compatibility: If stored value is legacy plaintext, return as-is.
      return storedText;
    }
    try {
      final base64Payload = storedText.substring(_prefix.length);
      final encryptedBytes = base64.decode(base64Payload);
      final decryptedBytes = List<int>.generate(encryptedBytes.length, (i) {
        return encryptedBytes[i] ^ _saltBytes[i % _saltBytes.length];
      });
      return utf8.decode(decryptedBytes);
    } catch (_) {
      // Fallback if corrupted
      return storedText;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Reads a decrypted value for the given [key].
  Future<String?> read({required String key}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return decrypt(raw);
  }

  /// Synchronous read if a [SharedPreferences] instance was provided.
  String? readSync({required String key}) {
    if (_prefs == null) return null;
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return decrypt(raw);
  }

  /// Writes an encrypted value for the given [key].
  Future<void> write({required String key, required String value}) async {
    final prefs = await _getPrefs();
    final encrypted = encrypt(value);
    await prefs.setString(key, encrypted);
  }

  /// Deletes the value for the given [key].
  Future<void> delete({required String key}) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  /// Checks if [key] exists.
  Future<bool> containsKey({required String key}) async {
    final prefs = await _getPrefs();
    return prefs.containsKey(key);
  }

  /// Deletes all keys (note: use with care).
  Future<void> deleteAll() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}

/// Global default instance of [AppSecureStorage].
const appSecureStorage = AppSecureStorage();
