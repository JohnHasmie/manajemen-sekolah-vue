// Teacher → RPP Saya (TC047-TC054) deep flow.
//
// Verifies the lesson plan list loads, the FAB opens an AI generate
// sheet, the sheet is dismissable cleanly, and (when a plan exists)
// drilling into the detail screen and back works.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC047-TC054: RPP Saya deep flow',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC047: Open RPP Saya.
      final opened = await tapMenu(tester, 'RPP Saya');
      expect(opened, isTrue, reason: 'RPP Saya must be reachable');
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      debugPrint('✅ TC047 PASSED — RPP Saya opened');

      // TC048: List or empty-state renders.
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'RPP screen must render list content or empty state',
      );
      debugPrint('✅ TC048 PASSED — RPP body rendered');

      // TC049: FAB exists and opens generate sheet.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'RPP screen must expose a FAB');
      await tester.tap(fab.first, warnIfMissed: false);
      await pumpFor(tester, count: 20);

      final sheetOpen =
          find.byType(TextField).evaluate().isNotEmpty ||
          find
              .textContaining(
                RegExp(
                  'Generasi|Buat|Mata Pelajaran|Kelas|Bab',
                  caseSensitive: false,
                ),
              )
              .evaluate()
              .isNotEmpty;
      expect(
        sheetOpen,
        isTrue,
        reason: 'FAB on RPP screen must open a sheet with generate form',
      );
      await binding.takeScreenshot('TC049_rpp_generate_sheet');
      debugPrint('✅ TC049 PASSED — Generate sheet opened');

      // TC050: Sheet must be dismissable.
      await dismissSheet(tester);
      expectScreenLoaded('RPP list after dismiss');
      debugPrint('✅ TC050 PASSED — Sheet dismissed cleanly');

      // TC051: Search field interaction (optional).
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.tap(searchField.first, warnIfMissed: false);
        await tester.enterText(searchField.first, 'Bab 1');
        await pumpFor(tester);
        await tester.enterText(searchField.first, '');
        await pumpFor(tester);
      }
      debugPrint('✅ TC051 PASSED — Search interaction stable');

      // TC052: View toggle (summary / list) when present.
      for (final icon in const [
        Icons.view_list,
        Icons.grid_view_rounded,
        Icons.view_module_outlined,
      ]) {
        final t = find.byIcon(icon);
        if (t.evaluate().isNotEmpty) {
          await tester.tap(t.first, warnIfMissed: false);
          await pumpFor(tester);
          expectScreenLoaded('RPP after view toggle');
          break;
        }
      }
      debugPrint('✅ TC052 PASSED — View toggle stable');

      // TC053: Drill into a plan if any exist.
      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 24);
        expectScreenLoaded('RPP detail');
        await binding.takeScreenshot('TC053_rpp_detail');
        await goBack(tester);
        debugPrint('✅ TC053 PASSED — Detail opened and walked back');
      } else {
        debugPrint('  ⚠ No RPP entries — drill-down skipped');
      }

      // TC054: Back to dashboard.
      await goBack(tester);
      expectScreenLoaded('Dashboard after RPP');
      debugPrint('✅ TC054 PASSED — Back to dashboard');
    },
  );
}
