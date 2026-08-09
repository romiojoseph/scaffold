import 'package:flutter_test/flutter_test.dart';
import 'package:scaffold/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ScaffoldApp());
    expect(find.text('Scaffold'), findsWidgets);
  });
}
