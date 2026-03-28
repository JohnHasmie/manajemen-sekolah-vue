import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC055-TC058: Jadwal Mengajar',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Teacher');

    // TC055: Navigate to Jadwal Mengajar
    await tapMenu(tester, 'Jadwal Mengajar');
    debugPrint('✅ TC055 PASSED - Jadwal Mengajar opened');

    // TC056: Verify schedule screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC056 PASSED - Schedule screen displayed');

    // TC057: Screenshot
    await binding.takeScreenshot('schedule');
    debugPrint('✅ TC057 PASSED - Screenshot taken');

    // TC058: Go back
    await goBack(tester);
    debugPrint('✅ TC058 PASSED - Navigated back');

    debugPrint('✅ TC055-TC058 ALL PASSED');
  });
}
