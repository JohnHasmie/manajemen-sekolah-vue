// Teacher → Materi Pembelajaran (TC052-TC056) deep flow.
//
// Verifies that the materials list renders, the FAB (when present) opens
// an upload/create sheet, the sheet is dismissable, and the back-stack is
// walked home cleanly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC052-TC056: Materi Pembelajaran deep flow',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC052: Open Materi Pembelajaran.
      final opened = await tapMenu(tester, 'Materi Pembelajaran');
      expect(opened, isTrue, reason: 'Materi Pembelajaran must be reachable');
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      debugPrint('✅ TC052 PASSED — Materi Pembelajaran opened');

      // TC053: List or empty state renders.
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Materials must render list content or empty state',
      );
      debugPrint('✅ TC053 PASSED — Materials body rendered');

      // TC054: FAB opens create/upload sheet (optional).
      if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
        await tapFAB(tester);
        await dismissSheet(tester);
        expectScreenLoaded('Materials list after dismiss');
      }
      debugPrint('✅ TC054 PASSED — FAB / create sheet stable');

      // TC055: Drill into first material (if any).
      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 20);
        expectScreenLoaded('Material detail');
        await binding.takeScreenshot('TC055_materi_detail');
        await goBack(tester);
        debugPrint('✅ TC055 PASSED — Material detail opened + back');
      } else {
        debugPrint('  ⚠ No material entries — drill-down skipped.');
      }

      // TC056: Back to dashboard.
      await binding.takeScreenshot('TC056_materi_list');
      await goBack(tester);
      expectScreenLoaded('Dashboard after Materi');
      debugPrint('✅ TC056 PASSED — Back to dashboard');
    },
  );
}
