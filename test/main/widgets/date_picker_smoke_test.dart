import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/count_model.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/widgets/date_picker.dart';
import 'package:provider/provider.dart';

import '../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  setUp(resetTestHiveData);

  testWidgets('DatePicker supports date navigation and profile reset', (
    tester,
  ) async {
    final countModel = CountModel()..selectedProfile = Profile('Demo');

    await tester.pumpWidget(
      ChangeNotifierProvider<CountModel>.value(
        value: countModel,
        child: const MaterialApp(home: Scaffold(body: DatePicker())),
      ),
    );

    expect(find.text('Demo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsNothing);

    countModel.selectedProfile = Profile('Demo');
    await tester.pumpAndSettle();

    countModel.selectedProfile = null;
    await tester.pumpAndSettle();

    expect(find.text('Select Profile'), findsOneWidget);
  });
}
