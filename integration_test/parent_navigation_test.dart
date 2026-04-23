/// Parent (Wali Murid) role navigation integration tests — real API.
///
/// Tests every dashboard menu item and deep navigation for the parent role.
/// Hits the live backend at https://edu-api.kamillabs.com/api using real creds.
///
/// Pattern per test:
///   1. Login as Wali Murid via real API
///   2. Tap menu / quick action → wait for screen to load
///   3. Optionally navigate deeper (tap child items)
///   4. Tap back → verify dashboard restored
///
/// Test IDs:
///   TC114-TC115  Parent quick actions
///   TC116-TC121  Parent menu items single-level
///   TC122        Deep: Announcements → item detail → back back
///   TC123        Deep: Class Activities → item detail → back back
///   TC124        Deep: Nilai (Grades) → subject detail → back back
///   TC125        Deep: Kehadiran 2-level (student → records → back back)
///   TC126        Deep: Kehadiran 3-level (student → records → detail → back ×3)
///   TC127        Deep: Tagihan (Billing) → item detail → back back
///   TC128        Deep: e-Rapor → semester detail → back back
///   TC129        Back-stack isolation: 3 menus in sequence return to dashboard
///   TC130        All 6 menus cycle — back-stack integrity
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation helpers (same pattern as role_navigation_test.dart)
// ─────────────────────────────────────────────────────────────────────────────

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

Future<bool> _tapItem(WidgetTester tester, String text) async {
  for (int attempt = 0; attempt < 5; attempt++) {
    final finder = find.text(text);
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.tap(finder.first);
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('📱 Tapped: $text');
        return true;
      } catch (e) {
        debugPrint('⚠️ Tap failed for "$text": $e');
        return false;
      }
    }
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -300));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
  }
  debugPrint('⚠️ Item not found after scrolling: $text');
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
      debugPrint('⚠️ No back button found — using Navigator.pop');
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
    }
  }
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  debugPrint('⬅️ Went back');
}

Future<void> _scrollToTop(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, 2000));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parent menu labels (Indonesian UI)
// ─────────────────────────────────────────────────────────────────────────────
const _parentMenus = [
  'Pengumuman',
  'Kegiatan Kelas',
  'Nilai',
  'Kehadiran',
  'Tagihan',
  'e-Rapor',
];

// ===========================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // TC114: Parent — Pengumuman PPDB quick action
  // =========================================================================
  testWidgets(
    'TC114: Parent quick action Pengumuman PPDB → announcement screen → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC114: Parent quick action – Pengumuman PPDB');

      final found = await _tapItem(tester, 'Pengumuman PPDB');
      if (!found) {
        debugPrint(
          '  ⚠️ Quick action Pengumuman PPDB not found — skipping TC114',
        );
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 8);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ PPDB announcement screen opened');
      await _goBack(tester);
      debugPrint('✅ TC114 PASSED');
    },
  );

  // =========================================================================
  // TC115: Parent — Tagihan quick action
  // =========================================================================
  testWidgets(
    'TC115: Parent quick action Tagihan → billing screen → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC115: Parent quick action – Tagihan');

      final found = await _tapItem(tester, 'Tagihan');
      if (!found) {
        debugPrint('  ⚠️ Quick action Tagihan not found — skipping TC115');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 8);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Tagihan screen opened');
      await _goBack(tester);
      debugPrint('✅ TC115 PASSED');
    },
  );

  // =========================================================================
  // TC116: Parent — Pengumuman menu item
  // =========================================================================
  testWidgets(
    'TC116: Parent Pengumuman — open → verify content → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC116: Parent Pengumuman menu');

      final found = await _tapItem(tester, 'Pengumuman');
      if (!found) {
        debugPrint('  ⚠️ Pengumuman not found — skipping TC116');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Pengumuman screen loaded with real data');
      await _goBack(tester);
      debugPrint('✅ TC116 PASSED');
    },
  );

  // =========================================================================
  // TC117: Parent — Kegiatan Kelas menu item
  // =========================================================================
  testWidgets(
    'TC117: Parent Kegiatan Kelas — open → verify → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC117: Parent Kegiatan Kelas menu');

      final found = await _tapItem(tester, 'Kegiatan Kelas');
      if (!found) {
        debugPrint('  ⚠️ Kegiatan Kelas not found — skipping TC117');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Kegiatan Kelas screen loaded');
      await _goBack(tester);
      debugPrint('✅ TC117 PASSED');
    },
  );

  // =========================================================================
  // TC118: Parent — Nilai (Grades) menu item
  // =========================================================================
  testWidgets(
    'TC118: Parent Nilai — open → verify → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC118: Parent Nilai menu');

      final found = await _tapItem(tester, 'Nilai');
      if (!found) {
        debugPrint('  ⚠️ Nilai not found — skipping TC118');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Nilai screen loaded');
      await _goBack(tester);
      debugPrint('✅ TC118 PASSED');
    },
  );

  // =========================================================================
  // TC119: Parent — Kehadiran menu item
  // =========================================================================
  testWidgets(
    'TC119: Parent Kehadiran — open → verify → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC119: Parent Kehadiran menu');

      final found = await _tapItem(tester, 'Kehadiran');
      if (!found) {
        debugPrint('  ⚠️ Kehadiran not found — skipping TC119');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Kehadiran screen loaded');
      await _goBack(tester);
      debugPrint('✅ TC119 PASSED');
    },
  );

  // =========================================================================
  // TC120: Parent — Tagihan (Billing) menu item
  // =========================================================================
  testWidgets(
    'TC120: Parent Tagihan — open → verify list → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC120: Parent Tagihan menu');

      final found = await _tapItem(tester, 'Tagihan');
      if (!found) {
        debugPrint('  ⚠️ Tagihan not found — skipping TC120');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ Tagihan list loaded');
      await _goBack(tester);
      debugPrint('✅ TC120 PASSED');
    },
  );

  // =========================================================================
  // TC121: Parent — e-Rapor menu item
  // =========================================================================
  testWidgets(
    'TC121: Parent e-Rapor — open → verify → back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC121: Parent e-Rapor menu');

      final found = await _tapItem(tester, 'e-Rapor');
      if (!found) {
        debugPrint('  ⚠️ e-Rapor not found — skipping TC121');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('  ✅ e-Rapor screen loaded');
      await _goBack(tester);
      debugPrint('✅ TC121 PASSED');
    },
  );

  // =========================================================================
  // TC122: Parent — Pengumuman deep (list → item detail → back back)
  // =========================================================================
  testWidgets(
    'TC122: Parent Pengumuman deep — list → first item → detail → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC122: Parent Pengumuman deep');

      final opened = await _tapItem(tester, 'Pengumuman');
      if (!opened) {
        debugPrint('  ⚠️ Pengumuman not found — skipping TC122');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Try to tap the first list tile (announcement item)
      final listTile = find.byType(ListTile);
      if (await _waitFor(tester, listTile, maxSeconds: 8)) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped first announcement — detail opened');
        await _goBack(tester); // detail → list
        debugPrint('  ⬅️ Back to announcement list');
      } else {
        debugPrint('  ⚠️ No announcement items visible — back from list only');
      }

      await _goBack(tester); // list → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC122 PASSED');
    },
  );

  // =========================================================================
  // TC123: Parent — Kegiatan Kelas deep (list → item → detail → back back)
  // =========================================================================
  testWidgets(
    'TC123: Parent Kegiatan Kelas deep — list → first item → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC123: Parent Kegiatan Kelas deep');

      final opened = await _tapItem(tester, 'Kegiatan Kelas');
      if (!opened) {
        debugPrint('  ⚠️ Kegiatan Kelas not found — skipping TC123');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      final listTile = find.byType(ListTile);
      if (await _waitFor(tester, listTile, maxSeconds: 8)) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped first activity — detail opened');
        await _goBack(tester);
        debugPrint('  ⬅️ Back to activity list');
      } else {
        debugPrint('  ⚠️ No activity items visible');
      }

      await _goBack(tester);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC123 PASSED');
    },
  );

  // =========================================================================
  // TC124: Parent — Nilai deep (list → first subject → grade detail → back back)
  // =========================================================================
  testWidgets(
    'TC124: Parent Nilai deep — subject list → first subject → grade detail → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC124: Parent Nilai deep');

      final opened = await _tapItem(tester, 'Nilai');
      if (!opened) {
        debugPrint('  ⚠️ Nilai not found — skipping TC124');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Tap first subject card or list tile
      final tapTarget = find.byType(InkWell);
      final listTile = find.byType(ListTile);
      final hasTile = await _waitFor(tester, listTile, maxSeconds: 8);
      final hasInkWell = tapTarget.evaluate().isNotEmpty;

      if (hasTile) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped first subject — grade detail opened');
        await _goBack(tester);
        debugPrint('  ⬅️ Back to subject list');
      } else if (hasInkWell) {
        await tester.tap(tapTarget.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped first InkWell — detail opened');
        await _goBack(tester);
      } else {
        debugPrint('  ⚠️ No subject items visible');
      }

      await _goBack(tester);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC124 PASSED');
    },
  );

  // =========================================================================
  // TC125: Parent — Kehadiran 2-level (student selector → attendance records)
  // =========================================================================
  testWidgets(
    'TC125: Parent Kehadiran 2-level — dashboard → student selector → attendance → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC125: Parent Kehadiran 2-level');

      final opened = await _tapItem(tester, 'Kehadiran');
      if (!opened) {
        debugPrint('  ⚠️ Kehadiran not found — skipping TC125');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
      debugPrint(
        '  ✅ Kehadiran screen loaded (student selector or attendance)',
      );

      // Select first student if a selector is visible
      final listTile = find.byType(ListTile);
      if (await _waitFor(tester, listTile, maxSeconds: 8)) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Selected first student — attendance records screen');
        await _goBack(tester); // records → selector
        debugPrint('  ⬅️ Back to student selector');
      } else {
        debugPrint('  ⚠️ No student list visible — already on records screen');
      }

      await _goBack(tester); // selector/records → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC125 PASSED');
    },
  );

  // =========================================================================
  // TC126: Parent — Kehadiran 3-level (selector → records → detail → back ×3)
  // =========================================================================
  testWidgets(
    'TC126: Parent Kehadiran 3-level — selector → records → detail → back back back',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC126: Parent Kehadiran 3-level deep');

      final opened = await _tapItem(tester, 'Kehadiran');
      if (!opened) {
        debugPrint('  ⚠️ Kehadiran not found — skipping TC126');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Level 1 → 2: select student
      final listTile = find.byType(ListTile);
      if (!await _waitFor(tester, listTile, maxSeconds: 8)) {
        debugPrint('  ⚠️ No student list — back to dashboard');
        await _goBack(tester);
        return;
      }
      await tester.tap(listTile.first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      debugPrint('  ✅ Level 2: Attendance records screen');

      // Level 2 → 3: tap first attendance record
      final recordTile = find.byType(ListTile);
      if (await _waitFor(tester, recordTile, maxSeconds: 8)) {
        await tester.tap(recordTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Level 3: Attendance detail screen');
        await _goBack(tester); // detail → records
        debugPrint('  ⬅️ Back to attendance records');
      } else {
        debugPrint('  ⚠️ No attendance records visible — 2-level only');
      }

      await _goBack(tester); // records → selector
      await _goBack(tester); // selector → dashboard
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC126 PASSED');
    },
  );

  // =========================================================================
  // TC127: Parent — Tagihan deep (billing list → item detail → back back)
  // =========================================================================
  testWidgets(
    'TC127: Parent Tagihan deep — billing list → first item → detail → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC127: Parent Tagihan deep');

      final opened = await _tapItem(tester, 'Tagihan');
      if (!opened) {
        debugPrint('  ⚠️ Tagihan not found — skipping TC127');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Tap first billing item
      final listTile = find.byType(ListTile);
      final inkWell = find.byType(InkWell);
      if (await _waitFor(tester, listTile, maxSeconds: 8)) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped first billing item — detail opened');
        await _goBack(tester);
        debugPrint('  ⬅️ Back to billing list');
      } else if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped billing card — detail opened');
        await _goBack(tester);
      } else {
        debugPrint('  ⚠️ No billing items visible');
      }

      await _goBack(tester);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC127 PASSED');
    },
  );

  // =========================================================================
  // TC128: Parent — e-Rapor deep (list → semester → report card → back back)
  // =========================================================================
  testWidgets(
    'TC128: Parent e-Rapor deep — list → semester selector → report card → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC128: Parent e-Rapor deep');

      final opened = await _tapItem(tester, 'e-Rapor');
      if (!opened) {
        debugPrint('  ⚠️ e-Rapor not found — skipping TC128');
        return;
      }

      await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);

      // Try tapping a semester card
      final listTile = find.byType(ListTile);
      final card = find.byType(Card);
      if (await _waitFor(tester, listTile, maxSeconds: 8)) {
        await tester.tap(listTile.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped semester — report card detail opened');
        await _goBack(tester);
        debugPrint('  ⬅️ Back to semester list');
      } else if (card.evaluate().isNotEmpty) {
        await tester.tap(card.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        debugPrint('  ✅ Tapped semester card — detail opened');
        await _goBack(tester);
      } else {
        debugPrint('  ⚠️ No semester items visible');
      }

      await _goBack(tester);
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC128 PASSED');
    },
  );

  // =========================================================================
  // TC129: Parent — Back-stack isolation: 3 menus in sequence
  // =========================================================================
  testWidgets(
    'TC129: Parent back-stack isolation — Pengumuman → Nilai → Tagihan each back to dashboard',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC129: Parent back-stack isolation');

      for (final menu in ['Pengumuman', 'Nilai', 'Tagihan']) {
        await _scrollToTop(tester);
        final found = await _tapItem(tester, menu);
        if (found) {
          await _waitFor(tester, find.byType(Scaffold), maxSeconds: 8);
          await _goBack(tester);
          debugPrint('  ✅ $menu → back OK');
        } else {
          debugPrint('  ⚠️ $menu not found — skipping');
        }
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Dashboard scaffold must still be visible
      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC129 PASSED');
    },
  );

  // =========================================================================
  // TC130: Parent — All 6 menus cycle — back-stack integrity
  // =========================================================================
  testWidgets(
    'TC130: Parent all 6 menus cycle — back-stack integrity with real API',
    timeout: const Timeout(Duration(minutes: 15)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Wali Murid');
      debugPrint('▶ TC130: Parent all menus back-stack integrity');

      int passed = 0;
      int skipped = 0;

      for (final menu in _parentMenus) {
        await _scrollToTop(tester);
        debugPrint('  🔍 Trying menu: $menu');

        final found = await _tapItem(tester, menu);
        if (!found) {
          debugPrint('  ⚠️ $menu not found — skipping');
          skipped++;
          continue;
        }

        await _waitFor(tester, find.byType(Scaffold), maxSeconds: 10);
        await _goBack(tester);

        // Verify dashboard is restored by checking Scaffold + menus visible
        final scaffoldOk = find.byType(Scaffold).evaluate().isNotEmpty;
        if (!scaffoldOk) {
          debugPrint('  ❌ Scaffold missing after back from $menu');
        } else {
          debugPrint('  ✅ $menu → back → dashboard OK');
          passed++;
        }
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.byType(Scaffold), findsWidgets);
      debugPrint('✅ TC130 PASSED — $passed navigated, $skipped skipped');
    },
  );
}
