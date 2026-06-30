import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../core/encryption/encryption_service.dart';

/// Represents a stored password entry in the Vault.
class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String category;
  
  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.category = 'General',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category,
    };
  }

  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
      category: map['category'] ?? 'General',
    );
  }
}

/// Repository responsible for CRUD operations of PasswordEntries.
/// Data is encrypted using AES-256 before saving to Hive, and decrypted upon reading.
class VaultRepository {
  final EncryptionService _encryptionService;
  static const String _boxName = 'secure_vault_passwords';

  VaultRepository(this._encryptionService);

  /// Initializes the Hive box. Call this once during app startup.
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  /// Helper to check if vault is unlocked
  void _ensureUnlocked() {
    if (!_encryptionService.isUnlocked) {
      throw Exception('Vault is locked. Decryption unavailable.');
    }
  }

  /// Adds a new password entry to the vault.
  Future<void> addPassword(PasswordEntry entry) async {
    _ensureUnlocked();
    final plainTextJson = jsonEncode(entry.toMap());
    final encryptedData = _encryptionService.encrypt(plainTextJson);
    await _box.put(entry.id, encryptedData);
  }

  /// Updates an existing password entry.
  Future<void> updatePassword(PasswordEntry entry) async {
    _ensureUnlocked();
    if (!_box.containsKey(entry.id)) {
      throw Exception('Password entry not found.');
    }
    final plainTextJson = jsonEncode(entry.toMap());
    final encryptedData = _encryptionService.encrypt(plainTextJson);
    await _box.put(entry.id, encryptedData);
  }

  /// Deletes a password entry from the vault.
  Future<void> deletePassword(String id) async {
    await _box.delete(id);
  }

  /// Retrieves all password entries from the vault.
  Future<List<PasswordEntry>> getAllPasswords() async {
    _ensureUnlocked();
    final List<PasswordEntry> entries = [];
    
    for (final encryptedData in _box.values) {
      try {
        final plainTextJson = _encryptionService.decrypt(encryptedData);
        final map = jsonDecode(plainTextJson) as Map<String, dynamic>;
        entries.add(PasswordEntry.fromMap(map));
      } catch (e) {
        // Log or handle individual decryption failures (e.g. data corruption)
      }
    }
    return entries;
  }
}
