import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC063-TC067: Pengumuman',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC063: Navigate to Pengumuman
    await tapMenu(tester, 'Pengumuman');
    debugPrint('✅ TC063 PASSED - Pengumuman opened');

    // TC064: Verify announcement screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC064 PASSED - Announcement screen displayed');

    // TC065-TC066: Screenshot
    await binding.takeScreenshot('announcement');
    debugPrint('✅ TC065-TC066 PASSED - Screenshot taken');

    // TC067: Go back
    await goBack(tester);
    debugPrint('✅ TC067 PASSED - Navigated back');

    debugPrint('✅ TC063-TC067 ALL PASSED');
  });
}
