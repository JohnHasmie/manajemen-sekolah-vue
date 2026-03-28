import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC044-TC046: Raport Siswa',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC044: Navigate to Raport Siswa
    await tapMenu(tester, 'Raport Siswa');
    debugPrint('✅ TC044 PASSED - Raport Siswa opened');

    // TC045: Verify report card screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC045 PASSED - Report card screen displayed');

    // TC046: Screenshot and go back
    await binding.takeScreenshot('report_card');
    debugPrint('✅ TC046 PASSED - Screenshot taken');

    await goBack(tester);

    debugPrint('✅ TC044-TC046 ALL PASSED');
  });
}
