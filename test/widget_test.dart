import 'package:flutter_test/flutter_test.dart';

import 'package:time_tracker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TimeTrackerApp());
    expect(find.byType(TimeTrackerApp), findsOneWidget);
  });
}
