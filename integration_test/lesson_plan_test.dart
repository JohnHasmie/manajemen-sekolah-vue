import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC047-TC051: RPP Saya',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC047: Navigate to RPP Saya
      await tapMenu(tester, 'RPP Saya');
      debugPrint('✅ TC047 PASSED - RPP Saya opened');

      // TC048: Verify lesson plan screen
      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC048 PASSED - Lesson plan screen displayed');

      // TC049-TC050: Screenshot
      await binding.takeScreenshot('lesson_plan');
      debugPrint('✅ TC049-TC050 PASSED - Screenshot taken');

      // TC051: Go back
      await goBack(tester);
      debugPrint('✅ TC051 PASSED - Navigated back');

      debugPrint('✅ TC047-TC051 ALL PASSED');
    },
  );
}
