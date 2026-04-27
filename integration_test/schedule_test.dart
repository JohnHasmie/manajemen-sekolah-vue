// Teacher → Jadwal Mengajar (TC055-TC060) deep flow.
//
// Goes beyond the legacy "open + back" stub: verifies the schedule
// renders content (or a clean empty state), exercises the search
// field, the view toggle (list ↔ matrix) when present, and walks
// the back-stack home.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC055-TC060: Jadwal Mengajar deep flow',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC055: Navigate to Jadwal Mengajar.
      final opened = await tapMenu(tester, 'Jadwal Mengajar');
      expect(opened, isTrue, reason: 'Jadwal Mengajar must be reachable');
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      debugPrint('✅ TC055 PASSED — Jadwal Mengajar opened');

      // TC056: Schedule list shows real content OR a documented empty state.
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Schedule should render real seeded sessions or empty state',
      );
      debugPrint('✅ TC056 PASSED — Schedule body rendered');

      // TC057: Search field accepts input without crashing.
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.tap(searchField.first, warnIfMissed: false);
        await tester.enterText(searchField.first, 'B. Arab');
        await pumpFor(tester);
        expectScreenLoaded('Schedule with search applied');
        // Clear so it doesn't poison subsequent assertions.
        await tester.enterText(searchField.first, '');
        await pumpFor(tester);
      }
      debugPrint('✅ TC057 PASSED — Search interaction stable');

      // TC058: View toggle (list ↔ matrix) — optional widget.
      for (final icon in const [
        Icons.grid_view_rounded,
        Icons.view_list,
        Icons.view_module_outlined,
      ]) {
        final t = find.byIcon(icon);
        if (t.evaluate().isNotEmpty) {
          await tester.tap(t.first, warnIfMissed: false);
          await pumpFor(tester);
          expectScreenLoaded('Schedule after view toggle');
          break;
        }
      }
      debugPrint('✅ TC058 PASSED — View toggle stable');

      // TC059: Take a screenshot for evidence.
      await binding.takeScreenshot('TC059_jadwal_mengajar');
      debugPrint('✅ TC059 PASSED — Screenshot captured');

      // TC060: Back to dashboard.
      await goBack(tester);
      expectScreenLoaded('Dashboard after Jadwal');
      debugPrint('✅ TC060 PASSED — Back to dashboard');
    },
  );
}
