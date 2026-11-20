import 'package:flutter_test/flutter_test.dart';
import 'package:traceitem_mobile/main.dart';

void main() {
  testWidgets('TraceItemApp smoke test and title check', (WidgetTester tester) async {
    await tester.pumpWidget(const TraceItemApp());
    await tester.pumpAndSettle();

    expect(find.text('按图索骥'), findsOneWidget);
  });
}
