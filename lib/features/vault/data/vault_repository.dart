import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../../../core/encryption/encryption_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'document_entry.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _boxName = 'secure_vault_passwords';
  static const String _docBoxName = 'secure_vault_documents';

  VaultRepository(this._encryptionService);

  /// Initializes the Hive box. Call this once during app startup.
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    if (!Hive.isBoxOpen(_docBoxName)) {
      await Hive.openBox<String>(_docBoxName);
    }
  }

  Box<String> get _box => Hive.box<String>(_boxName);
  Box<String> get _docBox => Hive.box<String>(_docBoxName);

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
    await _syncToCloud(entry.id, encryptedData);
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
    await _syncToCloud(entry.id, encryptedData);
  }

  Future<void> _syncToCloud(String id, String encryptedData) async {
    try {
      final cloudSyncId = await _secureStorage.read(key: 'cloud_sync_id');
      if (cloudSyncId != null) {
        await Supabase.instance.client.from('user_saved_pass_info').upsert({
          'id': id,
          'master_pass_hash': cloudSyncId,
          'encrypted_data': encryptedData,
        });
        print("Successfully synced password $id to cloud.");
      } else {
        print("cloud_sync_id is null, skipping cloud sync.");
      }
    } catch (e) {
      print("Error syncing password to cloud: $e");
    }
  }

  /// Deletes a password entry from the vault.
  Future<void> deletePassword(String id) async {
    await _box.delete(id);
    try {
      await Supabase.instance.client
          .from('user_saved_pass_info')
          .delete()
          .eq('id', id);
    } catch (e) {
      // Ignore if offline
    }
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

  /// Restores all passwords from Supabase for the current master password.
  Future<void> restoreFromCloud() async {
    _ensureUnlocked();
    try {
      final cloudSyncId = await _secureStorage.read(key: 'cloud_sync_id');
      if (cloudSyncId == null) {
        throw Exception('Cloud identity not found.');
      }
      
      final List<dynamic> records = await Supabase.instance.client
          .from('user_saved_pass_info')
          .select()
          .eq('master_pass_hash', cloudSyncId);
          
      for (var record in records) {
        final id = record['id'] as String;
        final encryptedData = record['encrypted_data'] as String;
        await _box.put(id, encryptedData);
      }
    } catch (e) {
      throw Exception('Failed to restore from cloud: $e');
    }
  }

  // --- Documents Methods ---

  /// Adds a new document entry and saves the encrypted image to disk.
  Future<void> addDocument(DocumentEntry entry, Uint8List imageBytes) async {
    _ensureUnlocked();
    
    // Encrypt the image bytes
    final encryptedBase64 = _encryptionService.encryptBytes(imageBytes);
    
    // Save to local file system
    final file = File(entry.localFilePath);
    await file.writeAsString(encryptedBase64);
    
    // Save metadata to Hive
    final plainTextJson = entry.toJson();
    final encryptedData = _encryptionService.encrypt(plainTextJson);
    await _docBox.put(entry.id, encryptedData);
    
    // Optional: cloud sync logic here if premium
  }

  /// Retrieves all document entries from the vault.
  Future<List<DocumentEntry>> getAllDocuments() async {
    _ensureUnlocked();
    final List<DocumentEntry> entries = [];
    
    for (final encryptedData in _docBox.values) {
      try {
        final plainTextJson = _encryptionService.decrypt(encryptedData);
        entries.add(DocumentEntry.fromJson(plainTextJson));
      } catch (e) {
        // Log or handle individual decryption failures
      }
    }
    return entries;
  }

  /// Gets the decrypted bytes of a document.
  Future<Uint8List> getDocumentBytes(String localFilePath) async {
    _ensureUnlocked();
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw Exception('Document file not found.');
    }
    
    final encryptedBase64 = await file.readAsString();
    return _encryptionService.decryptBytes(encryptedBase64);
  }

  /// Deletes a document entry.
  Future<void> deleteDocument(DocumentEntry entry) async {
    await _docBox.delete(entry.id);
    final file = File(entry.localFilePath);
    if (await file.exists()) {
      await file.delete();
    }
    // Also delete from cloud
    try {
      await Supabase.instance.client
          .from('user_saved_doc_info')
          .delete()
          .eq('id', entry.id);
    } catch (e) {
      // Ignore if offline
    }
  }

  /// Manually syncs all local documents to Supabase (premium only).
  /// Stores both encrypted metadata and encrypted image data in the table.
  Future<void> syncDocumentsToCloud() async {
    _ensureUnlocked();
    final cloudSyncId = await _secureStorage.read(key: 'cloud_sync_id');
    if (cloudSyncId == null) {
      throw Exception('Cloud identity not found.');
    }

    final documents = await getAllDocuments();
    for (final doc in documents) {
      try {
        // Read the encrypted image file from disk
        final file = File(doc.localFilePath);
        if (!await file.exists()) continue;
        final encryptedImageData = await file.readAsString();

        // Encrypted metadata is already in Hive, grab it
        final encryptedMeta = _docBox.get(doc.id);
        if (encryptedMeta == null) continue;

        await Supabase.instance.client.from('user_saved_doc_info').upsert({
          'id': doc.id,
          'master_pass_hash': cloudSyncId,
          'encrypted_meta': encryptedMeta,
          'encrypted_image': encryptedImageData,
        });
      } catch (e) {
        print('Error syncing document ${doc.id} to cloud: $e');
      }
    }
  }

  /// Restores all documents from Supabase (premium only).
  Future<void> restoreDocumentsFromCloud() async {
    _ensureUnlocked();
    final cloudSyncId = await _secureStorage.read(key: 'cloud_sync_id');
    if (cloudSyncId == null) {
      throw Exception('Cloud identity not found.');
    }

    final List<dynamic> records = await Supabase.instance.client
        .from('user_saved_doc_info')
        .select()
        .eq('master_pass_hash', cloudSyncId);

    for (var record in records) {
      try {
        final id = record['id'] as String;
        final encryptedMeta = record['encrypted_meta'] as String;
        final encryptedImageData = record['encrypted_image'] as String;

        // Save metadata to Hive
        await _docBox.put(id, encryptedMeta);

        // Decrypt metadata to get the local file path
        final plainTextJson = _encryptionService.decrypt(encryptedMeta);
        final doc = DocumentEntry.fromJson(plainTextJson);

        // Write encrypted image back to disk
        final file = File(doc.localFilePath);
        await file.writeAsString(encryptedImageData);
      } catch (e) {
        print('Error restoring document from cloud: $e');
      }
    }
  }
}
