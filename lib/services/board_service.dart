import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/board_message.dart';

class BoardService {
  BoardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const currentSchemaVersion = 2;
  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('messages');

  Stream<AppUser> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) throw StateError('Your user profile is missing.');
      return AppUser.fromFirestore(doc);
    });
  }

  Stream<List<BoardMessage>> watchMessages() {
    return _messages
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs.map(BoardMessage.fromFirestore).toList(),
        );
  }

  Future<void> postMessage({
    required User user,
    required String authorName,
    required String text,
    required String requestId,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > 500) {
      throw ArgumentError('Messages must contain 1 to 500 characters.');
    }
    final safeRequestId = requestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final reference = _messages.doc('${user.uid}_$safeRequestId');
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return;
      transaction.set(reference, {
        'text': cleanText,
        'authorUid': user.uid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'schemaVersion': currentSchemaVersion,
        'clientRequestId': requestId,
      });
    });
  }

  Future<void> editMessage({required String messageId, required String text}) {
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > 500) {
      throw ArgumentError('Messages must contain 1 to 500 characters.');
    }
    return _messages.doc(messageId).update({
      'text': cleanText,
      'editedAt': FieldValue.serverTimestamp(),
      'schemaVersion': currentSchemaVersion,
    });
  }

  Future<void> deleteMessage(String messageId) =>
      _messages.doc(messageId).delete();
}
