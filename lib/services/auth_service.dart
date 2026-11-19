import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a user after registration.');
    }

    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    await user.updateDisplayName('$cleanFirstName $cleanLastName'.trim());

    final reference = _firestore.collection('users').doc(user.uid);
    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) return;
        transaction.set(reference, {
          'uid': user.uid,
          'firstName': cleanFirstName,
          'lastName': cleanLastName,
          'role': role,
          'registrationDateTime': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
