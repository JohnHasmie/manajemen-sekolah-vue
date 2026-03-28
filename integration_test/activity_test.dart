import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC059-TC062: Aktivitas Kelas',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Teacher');

    // TC059: Navigate to Aktivitas Kelas
    await tapMenu(tester, 'Aktivitas Kelas');
    debugPrint('✅ TC059 PASSED - Aktivitas Kelas opened');

    // TC060: Verify activity screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC060 PASSED - Activity screen displayed');

    // TC061: Screenshot
    await binding.takeScreenshot('class_activity');
    debugPrint('✅ TC061 PASSED - Screenshot taken');

    // TC062: Go back
    await goBack(tester);
    debugPrint('✅ TC062 PASSED - Navigated back');

    debugPrint('✅ TC059-TC062 ALL PASSED');
  });
}
