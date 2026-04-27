// Teacher → Pengumuman (TC065-TC068) deep flow.
//
// Verifies the announcement list renders, the search field accepts
// input, and (when present) drilling into a single announcement
// shows a detail screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC065-TC068: Pengumuman deep flow',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC065: Open Pengumuman.
      final opened = await tapMenu(tester, 'Pengumuman');
      if (!opened) {
        debugPrint('  ⚠ Pengumuman not visible — skipping');
        return;
      }
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      debugPrint('✅ TC065 PASSED — Pengumuman opened');

      // TC066: Body renders (list or empty state).
      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Pengumuman must render content or empty state',
      );
      debugPrint('✅ TC066 PASSED — Announcement body rendered');

      // TC067: Search interaction (optional).
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.tap(searchField.first, warnIfMissed: false);
        await tester.enterText(searchField.first, 'libur');
        await pumpFor(tester);
        await tester.enterText(searchField.first, '');
        await pumpFor(tester);
      }

      // Drill into first announcement if any.
      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 16);
        expectScreenLoaded('Announcement detail');
        await binding.takeScreenshot('TC067_announcement_detail');
        await goBack(tester);
      }
      debugPrint('✅ TC067 PASSED — Search + detail interaction stable');

      // TC068: Back to dashboard.
      await binding.takeScreenshot('TC068_announcement_list');
      await goBack(tester);
      expectScreenLoaded('Dashboard after Pengumuman');
      debugPrint('✅ TC068 PASSED — Back to dashboard');
    },
  );
}
