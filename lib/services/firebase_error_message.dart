import 'package:firebase_auth/firebase_auth.dart';

String friendlyFirebaseError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already uses that email.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a password with at least six characters.',
      'network-request-failed' =>
        'The network is unavailable. Try again when connected.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      _ => 'Authentication could not be completed. Please try again.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore denied this action. Your account may not own this message.',
      'unavailable' =>
        'The board is temporarily unavailable. A pending write may sync later.',
      'deadline-exceeded' =>
        'The request took too long. Check your connection and try again.',
      _ => 'The board could not complete that action. Please try again.',
    };
  }
  return 'Something unexpected happened. Please try again.';
}
