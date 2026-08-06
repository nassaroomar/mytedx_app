import 'package:flutter_test/flutter_test.dart';

import 'package:mytedx_app/main.dart';

void main() {
  testWidgets('App boots with bottom navigation', (tester) async {
    await tester.pumpWidget(const MyTEDxApp());
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });
}
