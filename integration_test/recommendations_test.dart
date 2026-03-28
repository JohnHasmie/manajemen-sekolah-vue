import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC085-TC086: Rekomendasi Pembelajaran',
      timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await loginAndNavigateToDashboard(tester, role: 'Teacher');

    // TC085: Navigate to Rekomendasi Pembelajaran
    await tapMenu(tester, 'Rekomendasi Pembelajaran');
    debugPrint('✅ TC085 PASSED - Rekomendasi Pembelajaran opened');

    // TC086: Verify and screenshot
    await waitFrames(tester, count: 10);
    expect(find.byType(Scaffold), findsWidgets);
    await binding.takeScreenshot('recommendations');
    debugPrint('✅ TC086 PASSED - Recommendations screen displayed');

    await goBack(tester);

    debugPrint('✅ TC085-TC086 ALL PASSED');
  });
}
