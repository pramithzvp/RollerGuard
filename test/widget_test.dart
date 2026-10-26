import 'package:flutter_test/flutter_test.dart';

import 'package:roller_guard/main.dart';

void main() {
  testWidgets('RollerGuard shows the initial demo control state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RollerGuardApp());
    await tester.pumpAndSettle();

    expect(find.text('RollerGuard'), findsOneWidget);
    expect(
      find.text(
        'DEMO ONLY — No motor, Wi-Fi relay, or real users are connected.',
      ),
      findsOneWidget,
    );
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('REMOTE LOCKED'), findsOneWidget);
  });
}
