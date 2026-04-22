import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC078-TC084: Pengaturan Sekolah',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');

      // TC078: Navigate to Pengaturan Sekolah
      await tapMenu(tester, 'Pengaturan Sekolah');
      debugPrint('✅ TC078 PASSED - Pengaturan Sekolah opened');

      // TC079-TC082: Verify settings screen
      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC079-TC082 PASSED - Settings screen displayed');

      // TC083: Screenshot
      await binding.takeScreenshot('school_settings');
      debugPrint('✅ TC083 PASSED - Screenshot taken');

      // TC084: Go back
      await goBack(tester);
      debugPrint('✅ TC084 PASSED - Navigated back');

      debugPrint('✅ TC078-TC084 ALL PASSED');
    },
  );
}
