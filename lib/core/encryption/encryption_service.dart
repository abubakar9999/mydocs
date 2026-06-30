import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for all cryptographic operations in SecureVault.
/// It uses AES-256 for encryption and bcrypt for master password hashing.
class EncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // In-memory key for current session. Wiped when app locks.
  Key? _sessionKey;
  
  static const String _encryptionKeyStorageKey = 'aes_encryption_key';

  /// Hashes the master password using bcrypt.
  /// Used during initial setup or password change.
  String hashMasterPassword(String plainPassword) {
    return BCrypt.hashpw(plainPassword, BCrypt.gensalt());
  }

  /// Verifies a provided password against the stored bcrypt hash.
  bool verifyMasterPassword(String plainPassword, String hashedPassword) {
    return BCrypt.checkpw(plainPassword, hashedPassword);
  }

  /// Derives an AES-256 key (32 bytes) from the master password using SHA-256.
  /// We derive a 32-byte key from the master password to use with AES-256.
  Key _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Key(Uint8List.fromList(digest.bytes));
  }

  /// Sets up the encryption key based on the master password and stores it 
  /// securely for biometric unlock later.
  Future<void> setupEncryptionKey(String masterPassword) async {
    _sessionKey = _deriveKey(masterPassword);
    
    // Store the derived key in secure storage so it can be retrieved via biometrics later
    await _secureStorage.write(
      key: _encryptionKeyStorageKey,
      value: _sessionKey!.base64,
    );
  }

  /// Loads the encryption key from secure storage into memory.
  /// Usually called after successful biometric auth.
  Future<bool> loadEncryptionKeyFromStorage() async {
    final keyBase64 = await _secureStorage.read(key: _encryptionKeyStorageKey);
    if (keyBase64 != null) {
      _sessionKey = Key.fromBase64(keyBase64);
      return true;
    }
    return false;
  }

  /// Wipes the session key from memory. Used for auto-lock.
  void wipeSessionKey() {
    _sessionKey = null;
  }

  /// Checks if the vault is currently unlocked (key in memory).
  bool get isUnlocked => _sessionKey != null;

  /// Encrypts plain text data using AES-256 (CBC mode).
  /// Appends the IV to the cipher text for decryption.
  String encrypt(String plainText) {
    if (_sessionKey == null) {
      throw Exception('Encryption key not loaded. Vault is locked.');
    }

    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_sessionKey!, mode: AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Return combined IV and ciphertext, separated by a colon
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts cipher text back to plain text.
  String decrypt(String encryptedData) {
    if (_sessionKey == null) {
      throw Exception('Encryption key not loaded. Vault is locked.');
    }

    final parts = encryptedData.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid encrypted data format.');
    }

    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    final encrypter = Encrypter(AES(_sessionKey!, mode: AESMode.cbc));

    return encrypter.decrypt(encrypted, iv: iv);
  }
}
