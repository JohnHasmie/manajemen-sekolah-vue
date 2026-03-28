import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC090-TC092+TC094: UI verification',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC090: Verify Scaffold exists
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC090 PASSED - Scaffold exists');

    // TC091: Verify no crash
    await waitFrames(tester, count: 5);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC091 PASSED - No crash detected');

    // TC092: Screenshot dashboard
    await binding.takeScreenshot('ui_dashboard_top');
    debugPrint('✅ TC092 PASSED - Dashboard screenshot taken');

    // TC094: Scroll down and screenshot
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -400));
      await waitFrames(tester, count: 5);
    }
    await binding.takeScreenshot('ui_dashboard_scrolled');
    debugPrint('✅ TC094 PASSED - Scrolled dashboard screenshot taken');

    debugPrint('✅ TC090-TC092+TC094 ALL PASSED');
  });
}
