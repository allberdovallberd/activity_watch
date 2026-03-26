import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:usage_collector/l10n/app_localizations.dart';

void main() {
  testWidgets('turkmen localization strings can render in a widget', (
    WidgetTester tester,
  ) async {
    final l10n = AppLocalizations.lookup('tr');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text(l10n.permissionsTitle),
              Text(l10n.usageAccess),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Rugsatlar'), findsOneWidget);
    expect(find.text('Ulanyş rugsady'), findsOneWidget);
  });
}
