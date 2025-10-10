import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surra_application/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SurraApp());
    expect(find.text('Welcome to Surra'), findsOneWidget);
  });
}
