import 'package:cloud_firestore/cloud_firestore.dart';

class BoardMessage {
  const BoardMessage({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.editedAt,
    required this.schemaVersion,
    required this.clientRequestId,
    required this.hasPendingWrites,
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final int schemaVersion;
  final String clientRequestId;
  final bool hasPendingWrites;

  factory BoardMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BoardMessage(
      id: doc.id,
      text: (data['text'] ?? data['content'] ?? '') as String,
      authorUid: (data['authorUid'] ?? data['ownerUid'] ?? '') as String,
      authorName:
          (data['authorName'] ?? data['ownerName'] ?? 'Unknown') as String,
      createdAt: _dateFrom(data['createdAt'] ?? data['timestamp']),
      editedAt: _dateFrom(data['editedAt']),
      schemaVersion: data['schemaVersion'] as int? ?? 1,
      clientRequestId: data['clientRequestId'] as String? ?? doc.id,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
