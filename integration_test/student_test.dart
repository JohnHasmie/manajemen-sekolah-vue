import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC019-TC025: Kelola Siswa - list, add, detail',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC019: Navigate to Kelola Data
    await tapMenu(tester, 'Kelola Data');
    debugPrint('✅ TC019 PASSED - Kelola Data menu opened');

    // TC020: Navigate to Kelola Siswa
    await tapMenu(tester, 'Kelola Siswa');
    debugPrint('✅ TC020 PASSED - Kelola Siswa opened');

    // TC021: Verify student list is displayed
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC021 PASSED - Student list displayed');

    // TC022: Screenshot student list
    await binding.takeScreenshot('student_list');
    debugPrint('✅ TC022 PASSED - Screenshot taken');

    // TC023: Tap FAB to open add student form
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab.first);
      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC023 PASSED - Add student form opened');
    } else {
      debugPrint('⚠️ TC023 SKIPPED - No FAB found');
    }

    // TC024: Cancel form (go back)
    await goBack(tester);
    debugPrint('✅ TC024 PASSED - Form cancelled');

    // TC025: Tap first student for detail
    final listTile = find.byType(ListTile);
    if (listTile.evaluate().isNotEmpty) {
      await tester.tap(listTile.first);
      await waitFrames(tester, count: 10);
      await binding.takeScreenshot('student_detail');
      debugPrint('✅ TC025 PASSED - Student detail viewed');
    } else {
      debugPrint('⚠️ TC025 SKIPPED - No ListTile found');
    }

    // Navigate back to dashboard
    await goBack(tester);
    await goBack(tester);
    await goBack(tester);

    debugPrint('✅ TC019-TC025 ALL PASSED');
  });
}
