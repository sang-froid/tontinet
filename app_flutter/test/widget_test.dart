import 'package:flutter_test/flutter_test.dart';
import 'package:tontinet/main.dart';

void main() {
  testWidgets("L'application démarre", (tester) async {
    await tester.pumpWidget(const TontiNetApp());
    expect(find.text('TontiNet'), findsOneWidget);
  });
}
