import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: shadcn.ShadcnApp(
          title: 'Test',
          theme: shadcn.ThemeData(colorScheme: shadcn.ColorSchemes.darkZinc),
          home: const shadcn.Scaffold(child: MainLayout()),
        ),
      ),
    );

    expect(find.byType(MainLayout), findsOneWidget);
  });
}
