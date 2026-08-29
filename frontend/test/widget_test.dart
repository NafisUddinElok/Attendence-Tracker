import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:att_system/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AttendanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('InClass'), findsWidgets);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
