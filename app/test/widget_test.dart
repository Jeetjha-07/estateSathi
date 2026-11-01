import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:estate_sathi/api.dart';
import 'package:estate_sathi/main.dart';

void main() {
  testWidgets('shows the login screen when signed out',
      (WidgetTester tester) async {
    Api.token = null;
    await tester.pumpWidget(const EstateSathiApp());

    expect(find.text('EstateSathi'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });
}
