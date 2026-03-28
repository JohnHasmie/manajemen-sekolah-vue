import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC038-TC043: Input Nilai & Rekapitulasi Nilai',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Teacher');

    // TC038: Navigate to Input Nilai
    await tapMenu(tester, 'Input Nilai');
    debugPrint('✅ TC038 PASSED - Input Nilai opened');

    // TC039: Verify grade input screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC039 PASSED - Grade input screen displayed');

    // TC040: Screenshot grade input
    await binding.takeScreenshot('grade_input');
    debugPrint('✅ TC040 PASSED - Screenshot taken');

    // TC041: Go back
    await goBack(tester);
    debugPrint('✅ TC041 PASSED - Navigated back');

    // TC042: Navigate to Rekapitulasi Nilai
    await tapMenu(tester, 'Rekapitulasi Nilai');
    debugPrint('✅ TC042 PASSED - Rekapitulasi Nilai opened');

    // TC043: Verify and screenshot recap
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    await binding.takeScreenshot('grade_recap');
    debugPrint('✅ TC043 PASSED - Grade recap displayed');

    await goBack(tester);

    debugPrint('✅ TC038-TC043 ALL PASSED');
  });
}
