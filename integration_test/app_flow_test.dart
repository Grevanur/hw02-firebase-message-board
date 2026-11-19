import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:message_board_vault/main.dart' as app;
import 'package:message_board_vault/services/board_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production Firebase full CRUD and edge-flow evidence', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await binding.convertFlutterSurfaceToImage();

    final previousUser = FirebaseAuth.instance.currentUser;
    if (previousUser != null) {
      final previousMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('authorUid', isEqualTo: previousUser.uid)
          .get();
      for (final message in previousMessages.docs) {
        await message.reference.delete();
      }
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
    }

    await _waitFor(tester, find.text('Register'));
    await binding.takeScreenshot('01_sign_in_screen');
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'vault.evidence.$stamp@example.com';
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Gowtham',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'Evidence',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'VaultTest!2026',
    );
    await binding.takeScreenshot('02_registration_complete');
    await tester.tap(find.text('Create account'));

    await _waitFor(tester, find.text('The board is intentionally empty'));
    await binding.takeScreenshot('03_empty_live_board');

    const original = 'Live CRUD evidence message';
    await tester.enterText(
      find.widgetWithText(TextField, 'Share something with the board…'),
      original,
    );
    await tester.tap(find.byTooltip('Post message'));
    await _waitFor(tester, find.byIcon(Icons.more_vert));
    await binding.takeScreenshot('04_created_message');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    const edited = 'Edited live — ownership confirmed';
    await tester.enterText(find.widgetWithText(TextField, 'Message'), edited);
    await tester.tap(find.text('Save'));
    await _waitFor(tester, find.text(edited));
    await binding.takeScreenshot('05_edited_message');

    final currentUser = FirebaseAuth.instance.currentUser!;
    final boardService = BoardService();
    const duplicateText = 'Exactly-once duplicate proof';
    const duplicateRequestId = 'proof-duplicate';
    await boardService.postMessage(
      user: currentUser,
      authorName: 'Gowtham Evidence',
      text: duplicateText,
      requestId: duplicateRequestId,
    );
    await boardService.postMessage(
      user: currentUser,
      authorName: 'Gowtham Evidence',
      text: duplicateText,
      requestId: duplicateRequestId,
    );
    await _waitFor(tester, find.text(duplicateText));
    expect(find.text(duplicateText), findsOneWidget);
    await binding.takeScreenshot('06_duplicate_submit_one_record');
    await boardService.deleteMessage('${currentUser.uid}_$duplicateRequestId');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await _waitFor(tester, find.text('The board is intentionally empty'));
    await binding.takeScreenshot('07_deleted_to_empty_state');

    await tester.tap(find.byTooltip('Sign out'));
    await _waitFor(tester, find.text('Open the board'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'WrongPassword!2026',
    );
    await tester.tap(find.text('Open the board'));
    await _waitFor(tester, find.text('The email or password is incorrect.'));
    await binding.takeScreenshot('08_safe_invalid_sign_in');
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for an expected UI element.');
}
