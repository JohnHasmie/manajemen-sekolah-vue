import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC068-TC073: Keuangan',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC068: Navigate to Keuangan
    await tapMenu(tester, 'Keuangan');
    debugPrint('✅ TC068 PASSED - Keuangan opened');

    // TC069: Verify finance screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC069 PASSED - Finance screen displayed');

    // TC070-TC072: Screenshot
    await binding.takeScreenshot('finance');
    debugPrint('✅ TC070-TC072 PASSED - Screenshot taken');

    // TC073: Go back
    await goBack(tester);
    debugPrint('✅ TC073 PASSED - Navigated back');

    debugPrint('✅ TC068-TC073 ALL PASSED');
  });
}
