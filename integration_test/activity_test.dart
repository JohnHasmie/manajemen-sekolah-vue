// Teacher → Aktivitas Kelas (TC059-TC064) deep flow.
//
// Verifies that the class activity list renders, the create
// affordance is present, optional filter dialog opens, and the
// back-stack walks cleanly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC059-TC064: Aktivitas Kelas deep flow',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC059: Open Aktivitas Kelas.
      final opened = await tapMenu(tester, 'Aktivitas Kelas');
      expect(opened, isTrue, reason: 'Aktivitas Kelas must be reachable');
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      debugPrint('✅ TC059 PASSED — Aktivitas Kelas opened');

      // TC060: Body renders.
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Aktivitas Kelas must render list content or empty state',
      );
      debugPrint('✅ TC060 PASSED — Activity body rendered');

      // TC061: Create affordance is present (FAB or "+" icon).
      final hasCreate =
          find.byType(FloatingActionButton).evaluate().isNotEmpty ||
          find.byIcon(Icons.add).evaluate().isNotEmpty;
      expect(
        hasCreate,
        isTrue,
        reason: 'Aktivitas Kelas should expose a create affordance',
      );
      debugPrint('✅ TC061 PASSED — Create affordance present');

      // TC062: Filter dialog opens (optional).
      for (final icon in const [
        Icons.tune,
        Icons.filter_list,
        Icons.filter_alt_outlined,
      ]) {
        final f = find.byIcon(icon);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await pumpFor(tester);
          // Dismiss whatever opened (dialog / bottom sheet).
          await dismissSheet(tester);
          expectScreenLoaded('Activity after filter dismiss');
          break;
        }
      }
      debugPrint('✅ TC062 PASSED — Filter interaction stable');

      // TC063: Drill into first activity if any.
      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 20);
        expectScreenLoaded('Activity detail');
        await binding.takeScreenshot('TC063_activity_detail');
        await goBack(tester);
        debugPrint('✅ TC063 PASSED — Detail opened and back');
      } else {
        debugPrint('  ⚠ No activities to drill into — skipped.');
      }

      // TC064: Back to dashboard.
      await binding.takeScreenshot('TC064_activity_list');
      await goBack(tester);
      expectScreenLoaded('Dashboard after Aktivitas Kelas');
      debugPrint('✅ TC064 PASSED — Back to dashboard');
    },
  );
}
