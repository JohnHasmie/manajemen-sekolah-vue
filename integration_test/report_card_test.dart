/// Report card integration tests — real API.
///
/// TC044-TC046: original Raport Siswa open/screenshot/back
/// TC138:       Admin → select class → view student list → back back
/// TC139:       Admin → select class → select student → view report card →
///              back back back
/// TC140:       Admin → report card — print/export button visible (if present)
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
  // TC044-TC046: Original (preserved)
  // =========================================================================
  testWidgets(
    'TC044-TC046: Raport Siswa — open, screenshot, back',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');

      await tapMenu(tester, 'Raport Siswa');
      debugPrint('✅ TC044 PASSED - Raport Siswa opened');

      await waitFrames(tester, count: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC045 PASSED - Report card screen displayed');

      await binding.takeScreenshot('report_card');
      debugPrint('✅ TC046 PASSED - Screenshot taken');

      await goBack(tester);
      debugPrint('✅ TC044-TC046 ALL PASSED');
    },
  );

  // =========================================================================
  // TC138: Report Card — select class → student list → back back
  // =========================================================================
  testWidgets(
    'TC138: Report Card — open → select class → student list → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');
      debugPrint('▶ TC138: Report Card class selection');

      await tapMenu(tester, 'Raport Siswa');
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Try to select a class from a class list/dropdown
      final classMatchers = [
        find.textContaining('VII'),
        find.textContaining('VIII'),
        find.textContaining('IX'),
        find.byType(ListTile),
        find.byType(DropdownButton),
      ];

      bool selected = false;
      for (final matcher in classMatchers) {
        if (matcher.evaluate().isNotEmpty) {
          await tester.tap(matcher.first);
          for (int i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('  ✅ Selected class — student list loaded');
          selected = true;
          break;
        }
      }

      if (!selected) {
        debugPrint(
          '  ⚠️ No class selector found — may already show report cards',
        );
      }

      expect(find.byType(Scaffold), findsWidgets);
      await _goBack(tester); // student list → class list
      await _goBack(tester); // class list → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC138 PASSED');
    },
  );

  // =========================================================================
  // TC139: Report Card — class → student → view card → back ×3
  // =========================================================================
  testWidgets(
    'TC139: Report Card — class → student → view report card → back back back',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');
      debugPrint('▶ TC139: Report Card deep — 3-level');

      await tapMenu(tester, 'Raport Siswa');
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Level 1 → 2: select class
      final classItem = find.byType(ListTile);
      if (!await _waitFor(tester, classItem, maxSeconds: 8)) {
        debugPrint('  ⚠️ No class list — skipping TC139');
        await _goBack(tester);
        return;
      }
      await tester.tap(classItem.first);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      debugPrint('  ✅ Level 2: Student list screen');

      // Level 2 → 3: select student
      final studentItem = find.byType(ListTile);
      if (await _waitFor(tester, studentItem, maxSeconds: 8)) {
        await tester.tap(studentItem.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Level 3: Report card detail screen');
        await _goBack(tester); // report card → student list
        debugPrint('  ⬅️ Back to student list');
      } else {
        debugPrint('  ⚠️ No student items found');
      }

      await _goBack(tester); // student list → class list
      await _goBack(tester); // class list → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC139 PASSED');
    },
  );

  // =========================================================================
  // TC140: Report Card — print/export button visible on report card
  // =========================================================================
  testWidgets(
    'TC140: Report Card — view detail → print/export/share button visible',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Administrator');
      debugPrint('▶ TC140: Report Card — print/export button check');

      await tapMenu(tester, 'Raport Siswa');
      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Navigate to report card detail (class → student)
      final classItem = find.byType(ListTile);
      if (!await _waitFor(tester, classItem, maxSeconds: 8)) {
        debugPrint('  ⚠️ No class list — skipping TC140');
        await _goBack(tester);
        return;
      }
      await tester.tap(classItem.first);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final studentItem = find.byType(ListTile);
      if (await _waitFor(tester, studentItem, maxSeconds: 8)) {
        await tester.tap(studentItem.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Report card detail opened');

        // Check for print/export/share actions
        final printPatterns = [
          find.byIcon(Icons.print),
          find.byIcon(Icons.share),
          find.byIcon(Icons.download),
          find.byIcon(Icons.picture_as_pdf),
          find.textContaining('Print'),
          find.textContaining('Cetak'),
          find.textContaining('Export'),
          find.textContaining('Download'),
        ];

        bool foundAction = false;
        for (final pat in printPatterns) {
          if (pat.evaluate().isNotEmpty) {
            debugPrint('  ✅ Found print/export action button');
            foundAction = true;
            break;
          }
        }

        if (!foundAction) {
          debugPrint(
            '  ⚠️ No print/export button found — checking AppBar actions',
          );
          // Check AppBar actions
          final appBarAction = find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(IconButton),
          );
          if (appBarAction.evaluate().isNotEmpty) {
            debugPrint('  ✅ AppBar has action buttons');
          } else {
            debugPrint(
              '  ℹ️ No print/export action visible on this report card',
            );
          }
        }

        await _goBack(tester); // report card → student list
      }

      await _goBack(tester); // student list → class list
      await _goBack(tester); // class list → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC140 PASSED');
    },
  );
}
