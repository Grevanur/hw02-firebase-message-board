import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:message_board_vault/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device B posts to the shared live board', (tester) async {
    const email = String.fromEnvironment('TEST_EMAIL');
    if (email.isEmpty) throw TestFailure('TEST_EMAIL is required.');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await binding.convertFlutterSurfaceToImage();
    await _waitFor(tester, find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Device',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'Bravo',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'VaultTest!2026',
    );
    await tester.tap(find.text('Create account'));
    await _waitFor(tester, find.text('The board is intentionally empty'));

    await tester.enterText(
      find.widgetWithText(TextField, 'Share something with the board…'),
      'Live update from device B',
    );
    await tester.tap(find.byTooltip('Post message'));
    await _waitFor(tester, find.byIcon(Icons.more_vert));
    await binding.takeScreenshot('11_device_b_posted_live_message');
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for an expected UI element.');
}
