import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_app/main.dart';

void main() {
  testWidgets('App renders sign-in page', (WidgetTester tester) async {
    await tester.pumpWidget(const ShoppingApp());

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
