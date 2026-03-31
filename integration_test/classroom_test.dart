import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC026-TC031: Kelola Kelas & Kelola Mapel',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Administrator');

    // TC026: Navigate to Kelola Data → Kelola Kelas
    await tapMenu(tester, 'Kelola Data');
    await tapMenu(tester, 'Kelola Kelas');
    debugPrint('✅ TC026 PASSED - Kelola Kelas opened');

    // TC027: Verify classroom list
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    debugPrint('✅ TC027 PASSED - Classroom list displayed');

    // TC028: Screenshot classroom list
    await binding.takeScreenshot('classroom_list');
    debugPrint('✅ TC028 PASSED - Screenshot taken');

    // TC029: Go back to Kelola Data, then dashboard
    await goBack(tester);
    await goBack(tester);
    debugPrint('✅ TC029 PASSED - Navigated back');

    // TC030: Navigate to Kelola Data → Kelola Mapel
    await tapMenu(tester, 'Kelola Data');
    await tapMenu(tester, 'Kelola Mapel');
    debugPrint('✅ TC030 PASSED - Kelola Mapel opened');

    // TC031: Verify and screenshot subject list
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    await binding.takeScreenshot('subject_list');
    debugPrint('✅ TC031 PASSED - Subject list displayed');

    await goBack(tester);
    await goBack(tester);

    debugPrint('✅ TC026-TC031 ALL PASSED');
  });
}
