import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App launches to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceApp());

    // The app should start on the login screen, not the attendance screen,
    // since a JWT is required before marking attendance.
    expect(find.text('Student Login'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}