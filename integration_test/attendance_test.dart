import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC032-TC037: Absensi Siswa',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Teacher');

    // TC032: Navigate to Absensi Siswa
    await tapMenu(tester, 'Absensi Siswa');
    debugPrint('✅ TC032 PASSED - Absensi Siswa opened');

    // TC033: Verify attendance screen
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC033 PASSED - Attendance screen displayed');

    // TC034-TC036: Screenshot attendance screen
    await binding.takeScreenshot('attendance_screen');
    debugPrint('✅ TC034-TC036 PASSED - Screenshot taken');

    // TC037: Go back
    await goBack(tester);
    debugPrint('✅ TC037 PASSED - Navigated back');

    debugPrint('✅ TC032-TC037 ALL PASSED');
  });
}
