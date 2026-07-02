import 'dart:convert';

/// Represents a stored document/photo entry in the Vault.
class DocumentEntry {
  final String id;
  final String title;
  final String localFilePath;
  final DateTime dateAdded;
  
  DocumentEntry({
    required this.id,
    required this.title,
    required this.localFilePath,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'localFilePath': localFilePath,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory DocumentEntry.fromMap(Map<String, dynamic> map) {
    return DocumentEntry(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      localFilePath: map['localFilePath'] ?? '',
      dateAdded: map['dateAdded'] != null 
          ? DateTime.parse(map['dateAdded']) 
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DocumentEntry.fromJson(String source) => 
      DocumentEntry.fromMap(json.decode(source));
}
