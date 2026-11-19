import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.registrationDateTime,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime registrationDateTime;
  String get displayName => '$firstName $lastName'.trim();

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['registrationDateTime'] as Timestamp?;
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      registrationDateTime:
          timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
