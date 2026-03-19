import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/companion/inventory_counts_page.dart';
import 'package:inventory_count/companion/window_model.dart';
import 'package:inventory_count/companion_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanionApp', () {
    testWidgets('build returns configured MaterialApp', (tester) async {
      const app = CompanionApp();
      late MaterialApp built;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              built = app.build(context) as MaterialApp;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(built.debugShowCheckedModeBanner, isFalse);
      expect(built.theme?.useMaterial3, isTrue);
      expect(built.theme?.colorScheme.brightness, Brightness.dark);

      final home = built.home! as Scaffold;
      expect(home.body, isA<InventoryCountsPage>());

      final Widget wrapped = built.builder!(
        tester.element(find.byType(Builder)),
        const SizedBox.shrink(),
      );
      expect(wrapped, isA<WindowSetupWatcher>());
    });
  });
}
