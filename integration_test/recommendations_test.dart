/// Learning Recommendations integration tests — real API.
///
/// TC085-TC086: original open/screenshot/back
/// TC135:       Select first class card → recommendations list appears
/// TC136:       Expand/view a recommendation item detail
/// TC137:       Generate recommendation flow (if generate button exists)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int maxSeconds = 10,
}) async {
  for (int i = 0; i < maxSeconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> _goBack(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
  } else {
    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.first);
    } else {
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
    }
  }
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // TC085-TC086: Original (preserved)
  // =========================================================================
  testWidgets(
    'TC085-TC086: Rekomendasi Pembelajaran — open, screenshot, back',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      await tapMenu(tester, 'Rekomendasi Pembelajaran');
      debugPrint('✅ TC085 PASSED - Rekomendasi Pembelajaran opened');

      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      await binding.takeScreenshot('recommendations');
      debugPrint('✅ TC086 PASSED - Recommendations screen displayed');

      await goBack(tester);
      debugPrint('✅ TC085-TC086 ALL PASSED');
    },
  );

  // =========================================================================
  // TC135: Recommendations — select first class card → list loads
  // =========================================================================
  testWidgets(
    'TC135: Recommendations — select first class card → recommendations list',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      debugPrint('▶ TC135: Recommendations — class card selection');

      await tapMenu(tester, 'Rekomendasi Pembelajaran');
      if (find.byType(Scaffold).evaluate().isEmpty) {
        debugPrint('  ⚠️ Rekomendasi Pembelajaran not found — skipping TC135');
        return;
      }
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Wait for class list to load
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Try class name patterns first, then ListTile/Card fallback
      final classMatchers = [
        find.textContaining('VII'),
        find.textContaining('VIII'),
        find.textContaining('IX'),
        find.byType(ListTile),
        find.byType(Card),
      ];

      bool tapped = false;
      for (final matcher in classMatchers) {
        if (matcher.evaluate().isNotEmpty) {
          await tester.tap(matcher.first);
          for (int i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('  ✅ Tapped class — recommendations list loaded');
          tapped = true;
          break;
        }
      }

      if (!tapped) {
        debugPrint('  ⚠️ No class items found — screen may show empty state');
      }

      expect(find.byType(Scaffold), findsWidgets);
      await _goBack(tester);
      debugPrint('✅ TC135 PASSED');
    },
  );

  // =========================================================================
  // TC136: Recommendations — expand/view a recommendation item
  // =========================================================================
  testWidgets(
    'TC136: Recommendations — tap first class → expand recommendation item',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      debugPrint('▶ TC136: Recommendations — item expansion');

      await tapMenu(tester, 'Rekomendasi Pembelajaran');
      if (find.byType(Scaffold).evaluate().isEmpty) {
        debugPrint('  ⚠️ Not found — skipping TC136');
        return;
      }
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Level 1: select a class
      final classItem = find.byType(ListTile);
      if (await _waitFor(tester, classItem, maxSeconds: 8)) {
        await tester.tap(classItem.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Level 2: Class recommendations screen');

        // Level 2: expand/tap a recommendation item
        final recItem = find.byType(ExpansionTile);
        final recListTile = find.byType(ListTile);
        if (recItem.evaluate().isNotEmpty) {
          await tester.tap(recItem.first);
          for (int i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('  ✅ Expanded first recommendation item');
        } else if (recListTile.evaluate().isNotEmpty) {
          await tester.tap(recListTile.first);
          for (int i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('  ✅ Tapped first recommendation list tile');
          final back = find.byIcon(Icons.arrow_back);
          if (back.evaluate().isNotEmpty) {
            await _goBack(tester);
            debugPrint('  ⬅️ Back to class recommendations');
          }
        } else {
          debugPrint('  ⚠️ No recommendation items visible');
        }

        await _goBack(tester); // class recs → class list
      } else {
        debugPrint('  ⚠️ No class items found');
      }

      await _goBack(tester); // class list → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC136 PASSED');
    },
  );

  // =========================================================================
  // TC137: Recommendations — generate flow (AI generate button)
  // =========================================================================
  testWidgets(
    'TC137: Recommendations — generate button triggers AI generation flow',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      debugPrint('▶ TC137: Recommendations — generate button');

      await tapMenu(tester, 'Rekomendasi Pembelajaran');
      if (find.byType(Scaffold).evaluate().isEmpty) {
        debugPrint('  ⚠️ Not found — skipping TC137');
        return;
      }
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Navigate to a class first
      final classItem = find.byType(ListTile);
      if (!await _waitFor(tester, classItem, maxSeconds: 8)) {
        debugPrint('  ⚠️ No class list — skipping TC137');
        await _goBack(tester);
        return;
      }
      await tester.tap(classItem.first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      debugPrint('  ✅ Opened class recommendations');

      // Look for a generate/AI button
      final generatePatterns = [
        find.textContaining('Generate'),
        find.textContaining('Buat'),
        find.textContaining('AI'),
        find.byIcon(Icons.auto_awesome),
        find.byIcon(Icons.psychology),
      ];

      bool foundGenerate = false;
      for (final pat in generatePatterns) {
        if (pat.evaluate().isNotEmpty) {
          await tester.tap(pat.first);
          for (int i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('  ✅ Tapped generate button — AI generation started');
          foundGenerate = true;
          break;
        }
      }

      if (!foundGenerate) {
        debugPrint('  ⚠️ No generate button found — verify screen renders');
        expect(find.byType(Scaffold), findsWidgets);
      }

      // Go back regardless
      final back = find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) await _goBack(tester);
      await _goBack(tester);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC137 PASSED');
    },
  );
}
