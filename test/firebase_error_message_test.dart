import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board_vault/services/firebase_error_message.dart';

void main() {
  group('friendlyFirebaseError', () {
    test('does not reveal whether an account exists', () {
      final wrongPassword = friendlyFirebaseError(
        FirebaseAuthException(code: 'wrong-password'),
      );
      final unknownUser = friendlyFirebaseError(
        FirebaseAuthException(code: 'user-not-found'),
      );

      expect(wrongPassword, unknownUser);
      expect(wrongPassword, contains('email or password'));
    });

    test('gives a useful network message', () {
      final message = friendlyFirebaseError(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      expect(message, contains('network'));
    });

    test('hides unexpected implementation details', () {
      final message = friendlyFirebaseError(
        StateError('secret internal detail'),
      );

      expect(message, isNot(contains('secret')));
      expect(message, contains('unexpected'));
    });
  });
}
