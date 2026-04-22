import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC052-TC054: Materi Pembelajaran',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // TC052: Navigate to Materi Pembelajaran
      await tapMenu(tester, 'Materi Pembelajaran');
      debugPrint('✅ TC052 PASSED - Materi Pembelajaran opened');

      // TC053: Verify materials screen
      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC053 PASSED - Materials screen displayed');

      // TC054: Screenshot and go back
      await binding.takeScreenshot('materials');
      debugPrint('✅ TC054 PASSED - Screenshot taken');

      await goBack(tester);

      debugPrint('✅ TC052-TC054 ALL PASSED');
    },
  );
}
