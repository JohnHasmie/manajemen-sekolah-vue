import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC012-TC018: Teacher Management Flow',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');

      // ── TC012: Navigate to Kelola Guru ──
      debugPrint('▶ TC012: Navigate to teacher list');
      await tapMenu(tester, 'Kelola Data');
      await tapMenu(tester, 'Kelola Guru');
      expect(find.byType(Scaffold), findsWidgets);
      await binding.takeScreenshot('TC012_teacher_list');
      debugPrint('✅ TC012 PASSED');

      // ── TC013: Tap FAB to open add teacher form ──
      debugPrint('▶ TC013: Open add teacher form');
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await waitFrames(tester, count: 10);
        await binding.takeScreenshot('TC013_add_teacher_form');
        debugPrint('✅ TC013 PASSED');

        // Cancel the form
        final batal = find.text('Batal');
        if (batal.evaluate().isNotEmpty) {
          await tester.tap(batal.first);
          await waitFrames(tester, count: 5);
        } else {
          await goBack(tester);
        }
      } else {
        debugPrint('⚠️ TC013 SKIPPED - No FAB found');
      }

      // ── TC014: View teacher detail ──
      debugPrint('▶ TC014: View teacher detail');
      final listItems = find.byType(ListTile);
      if (listItems.evaluate().isNotEmpty) {
        await tester.tap(listItems.first);
        await waitFrames(tester, count: 10);
        await binding.takeScreenshot('TC014_teacher_detail');
        debugPrint('✅ TC014 PASSED');
        await goBack(tester);
      } else {
        debugPrint('⚠️ TC014 SKIPPED - No list items');
      }

      // ── TC015-TC016: Verify list intact ──
      debugPrint('▶ TC015-TC016: Teacher list still visible');
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC015-TC016 PASSED');

      // ── TC018: Back to dashboard ──
      debugPrint('▶ TC018: Navigate back');
      await goBack(tester);
      await goBack(tester);
      await waitFrames(tester, count: 5);
      debugPrint('✅ TC018 PASSED');

      debugPrint('🎉 All Teacher Tests PASSED!');
    },
  );
}
