// Teacher → Input Nilai + Rekapitulasi Nilai (TC041-TC046) deep flow.
//
// Covers both grade entry and grade recap from a single test run:
// 1. Open Input Nilai, verify filter affordance + content.
// 2. Open Rekapitulasi Nilai, drill 3 levels deep (class → subject → table)
//    and walk back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC041-TC046: Input Nilai + Rekap Nilai deep flow',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // ── Input Nilai ────────────────────────────────────────────────
      // TC041: Open Input Nilai.
      var opened = await tapMenu(tester, 'Input Nilai');
      expect(opened, isTrue, reason: 'Input Nilai must be reachable');
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      debugPrint('✅ TC041 PASSED — Input Nilai opened');

      // TC042: Filter affordance is exposed (class/subject filter).
      final hasFilter =
          find.byIcon(Icons.tune).evaluate().isNotEmpty ||
          find.byIcon(Icons.filter_list).evaluate().isNotEmpty ||
          find.byIcon(Icons.filter_alt_outlined).evaluate().isNotEmpty;
      expect(
        hasFilter,
        isTrue,
        reason: 'Input Nilai must expose a filter affordance',
      );
      debugPrint('✅ TC042 PASSED — Filter affordance present');

      // TC043: Body renders (table or empty-state).
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Input Nilai must render table or empty state',
      );
      await binding.takeScreenshot('TC043_input_nilai');
      debugPrint('✅ TC043 PASSED — Input Nilai body rendered');

      // Walk back to dashboard before opening Rekap.
      await goBack(tester);
      expectScreenLoaded('Dashboard after Input Nilai');

      // ── Rekap Nilai ───────────────────────────────────────────────
      // TC044: Open Rekapitulasi Nilai.
      opened = await tapMenu(tester, 'Rekapitulasi Nilai');
      if (!opened) {
        debugPrint('  ⚠ Rekapitulasi Nilai not visible — skipping');
        return;
      }
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      debugPrint('✅ TC044 PASSED — Rekap opened');

      // TC045: Wizard 3 levels deep — class → subject → grade table.
      var stepped = await tapFirstListItem(tester);
      if (stepped) {
        await pumpFor(tester, count: 16);
        stepped = await tapFirstListItem(tester);
        if (stepped) {
          await pumpFor(tester, count: 16);
          expectScreenLoaded('Rekap subject grade table');
          await binding.takeScreenshot('TC045_rekap_subject_table');
          await goBack(tester);
          debugPrint('✅ TC045 PASSED — Drilled 3 levels and back 1');
        }
        await goBack(tester);
      }

      // TC046: Final back to dashboard.
      await goBack(tester);
      expectScreenLoaded('Dashboard after Rekap');
      debugPrint('✅ TC046 PASSED — Back to dashboard');
    },
  );
}
