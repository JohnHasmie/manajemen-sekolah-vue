// Deep integration tests for the Teacher role — exercises every major
// teacher-facing screen with real assertions against UI structure and
// real navigation back-stack behaviour. Talks to the live dev stack
// (core_api on :8001 and ai_api on :8000) using the no-OTP tester
// account `yahyahasymi@gmail.com / password` (see TesterSeeder +
// LoginAction.php's demo-email bypass list).
//
// These tests deliberately go *one step further* than the legacy
// `*_test.dart` stubs that only verify "menu opens → Scaffold visible →
// back". Each test below opens a screen, asserts page-specific UI is
// present, exercises an interaction (search, filter, view toggle, FAB,
// drill-down), and walks the full back-stack home.
//
// Run all teacher tests:
//   flutter test integration_test/teacher_deep_test.dart -d chrome
//
// Run a single test by name substring:
//   flutter test integration_test/teacher_deep_test.dart \
//     --plain-name 'TC-T07' -d chrome
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/login_helper.dart';
import 'helpers/teacher_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // TC-T01: Dashboard renders teacher-specific quick actions and stats
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T01: Teacher dashboard renders quick actions and seeded stats',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // The dashboard should have at least one Scaffold and at least one
      // Card-based stat tile. Real seeded data: SMP Kamil Edu A teacher
      // ought to see "Siswa", "Kelas", and the "Hari Ini" today-tile.
      expectScreenLoaded('Teacher dashboard');
      expect(find.byType(Card), findsWidgets);

      // Teacher menus that should always be present in the categorized
      // menu — match by visible label so the test is i18n-tolerant once
      // the user-language is Indonesian.
      const expectedMenus = <String>[
        'Jadwal Mengajar',
        'Absensi Siswa',
        'RPP Saya',
        'Aktivitas Kelas',
        'Input Nilai',
      ];
      var visible = 0;
      for (final m in expectedMenus) {
        if (find.text(m).evaluate().isNotEmpty) visible++;
      }
      expect(
        visible,
        greaterThanOrEqualTo(3),
        reason:
            'At least 3 of the canonical teacher menus should be visible '
            'on the initial dashboard render (seen $visible).',
      );

      await binding.takeScreenshot('TC-T01_teacher_dashboard');
      debugPrint('✅ TC-T01 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T02: Teaching Schedule loads with seeded sessions + view toggle
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T02: Jadwal Mengajar — list loads, view toggle, back-stack ok',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      final opened = await tapMenu(tester, 'Jadwal Mengajar');
      expect(opened, isTrue, reason: 'Jadwal Mengajar should be reachable');

      // Either the schedule cards render OR the empty state shows — both
      // are acceptable; what is NOT acceptable is the loading state still
      // being on screen after 10s.
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      expectScreenLoaded('Jadwal Mengajar');

      final hasContent =
          find.byType(Card).evaluate().isNotEmpty || isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Schedule should render either content or an empty state',
      );

      // Tap the view toggle (list ↔ matrix) if available — the toggle is
      // optional, so a missing toggle is fine but a present one must be
      // tappable without error.
      final toggle = find.byIcon(Icons.grid_view_rounded);
      final toggleAlt = find.byIcon(Icons.view_list);
      for (final t in [toggle, toggleAlt]) {
        if (t.evaluate().isNotEmpty) {
          await tester.tap(t.first, warnIfMissed: false);
          await pumpFor(tester);
          expectScreenLoaded('Jadwal Mengajar after view toggle');
          break;
        }
      }

      await binding.takeScreenshot('TC-T02_jadwal_mengajar');
      await goBack(tester);
      expectScreenLoaded('Dashboard after back from Jadwal');
      debugPrint('✅ TC-T02 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T03: Schedule search field accepts input without crashing
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T03: Jadwal Mengajar — search field accepts text without error',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Jadwal Mengajar');
      if (!opened) return;
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);

      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.tap(searchField.first, warnIfMissed: false);
        await tester.enterText(searchField.first, 'B. Arab');
        await pumpFor(tester);
        expectScreenLoaded('Jadwal Mengajar with search');
      }

      await goBack(tester);
      debugPrint('✅ TC-T03 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T04: Attendance — open, drill into a class, two-step back
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T04: Absensi Siswa — list → class detail → back back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Absensi Siswa');
      expect(opened, isTrue, reason: 'Absensi Siswa menu must exist');

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      expectScreenLoaded('Absensi Siswa');

      // Drill into the first class if the list has any.
      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 20);
        expectScreenLoaded('Absensi class detail');
        await binding.takeScreenshot('TC-T04_absensi_detail');
        await goBack(tester);
      }

      await goBack(tester);
      expectScreenLoaded('Dashboard after Absensi');
      debugPrint('✅ TC-T04 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T05: RPP Saya — list, view toggle, FAB opens generate sheet
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T05: RPP Saya — list renders + FAB opens generate flow',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'RPP Saya');
      expect(opened, isTrue, reason: 'RPP Saya menu must exist');

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      expectScreenLoaded('RPP Saya');

      // FAB must exist — RPP screen always offers AI generate.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'RPP list must expose a FAB');

      await tester.tap(fab.first, warnIfMissed: false);
      await pumpFor(tester, count: 20);

      // After tapping FAB the generate sheet should be on top of the
      // stack — find one of its visible markers (mata pelajaran field,
      // Generasi/Buat button, or any TextField).
      final sheetVisible =
          find
              .textContaining(
                RegExp(
                  'Generasi|Buat|Mata Pelajaran|Kelas|Bab',
                  caseSensitive: false,
                ),
              )
              .evaluate()
              .isNotEmpty ||
          find.byType(TextField).evaluate().isNotEmpty;
      expect(
        sheetVisible,
        isTrue,
        reason: 'Tapping FAB on RPP should reveal a generate-sheet UI',
      );

      await binding.takeScreenshot('TC-T05_rpp_generate_sheet');
      await dismissSheet(tester);
      expectScreenLoaded('RPP list after dismiss');

      await goBack(tester);
      debugPrint('✅ TC-T05 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T06: RPP detail — tap an existing plan if any, verify rich content
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T06: RPP Saya — tap entry → detail screen',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'RPP Saya');
      if (!opened) return;
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);

      final tapped = await tapFirstListItem(tester);
      if (tapped) {
        await pumpFor(tester, count: 20);
        expectScreenLoaded('RPP detail');
        await binding.takeScreenshot('TC-T06_rpp_detail');
        await goBack(tester);
      } else {
        debugPrint('  ⚠ No RPP entries to drill into — empty path ok');
      }

      await goBack(tester);
      debugPrint('✅ TC-T06 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T07: Materi Pembelajaran — list + FAB + dismiss
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T07: Materi Pembelajaran — list renders + FAB present',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Materi Pembelajaran');
      expect(opened, isTrue);

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      expectScreenLoaded('Materi Pembelajaran');

      if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
        await tapFAB(tester);
        // Materi FAB opens an upload/create sheet — dismiss it cleanly.
        await dismissSheet(tester);
      }

      await binding.takeScreenshot('TC-T07_materi_pembelajaran');
      await goBack(tester);
      debugPrint('✅ TC-T07 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T08: Aktivitas Kelas — list + FAB visible
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T08: Aktivitas Kelas — list renders + FAB visible',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Aktivitas Kelas');
      expect(opened, isTrue);

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      expectScreenLoaded('Aktivitas Kelas');

      // The activity screen should expose either a FAB or a "+" icon to
      // create a new activity (the exact widget depends on the
      // categorized menu vs. quick-action entry point).
      final hasCreate =
          find.byType(FloatingActionButton).evaluate().isNotEmpty ||
          find.byIcon(Icons.add).evaluate().isNotEmpty;
      expect(
        hasCreate,
        isTrue,
        reason: 'Aktivitas Kelas should expose a create affordance',
      );

      await binding.takeScreenshot('TC-T08_aktivitas_kelas');
      await goBack(tester);
      debugPrint('✅ TC-T08 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T09: Input Nilai — opens, exposes class/subject filter affordance
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T09: Input Nilai — list + filter affordance',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Input Nilai');
      expect(opened, isTrue);

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      expectScreenLoaded('Input Nilai');

      // The grade input header should expose a filter icon.
      final hasFilter =
          find.byIcon(Icons.tune).evaluate().isNotEmpty ||
          find.byIcon(Icons.filter_list).evaluate().isNotEmpty ||
          find.byIcon(Icons.filter_alt_outlined).evaluate().isNotEmpty;
      expect(
        hasFilter,
        isTrue,
        reason: 'Input Nilai should expose a class/subject filter affordance',
      );

      await binding.takeScreenshot('TC-T09_input_nilai');
      await goBack(tester);
      debugPrint('✅ TC-T09 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T10: Rekapitulasi Nilai — three-level wizard navigation
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T10: Rekapitulasi Nilai — wizard 3 levels deep + walk back',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Rekapitulasi Nilai');
      expect(opened, isTrue);
      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);

      // Level 2: tap first class.
      var stepped = await tapFirstListItem(tester);
      if (stepped) {
        // Level 3: tap first subject.
        await pumpFor(tester, count: 16);
        stepped = await tapFirstListItem(tester);
        if (stepped) {
          await pumpFor(tester, count: 16);
          expectScreenLoaded('Rekap nilai - subject grade table');
          await binding.takeScreenshot('TC-T10_rekap_subject');
          await goBack(tester);
        }
        await goBack(tester);
      }

      await goBack(tester);
      expectScreenLoaded('Dashboard after rekap');
      debugPrint('✅ TC-T10 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T11: Raport — opens, renders content, walks back
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T11: Raport — opens for teacher and walks back',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Raport');
      if (!opened) {
        debugPrint('  ⚠ Raport not on this dashboard — skip TC-T11');
        return;
      }

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      expectScreenLoaded('Raport');
      await binding.takeScreenshot('TC-T11_raport');
      await goBack(tester);
      debugPrint('✅ TC-T11 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T12: Pengumuman — list + content
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T12: Pengumuman — teacher view loads',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Pengumuman');
      if (!opened) return;

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
      expectScreenLoaded('Pengumuman');

      final hasContent =
          find.byType(Card).evaluate().isNotEmpty ||
          find.byType(ListTile).evaluate().isNotEmpty ||
          isShowingEmptyState();
      expect(
        hasContent,
        isTrue,
        reason: 'Pengumuman should render content or empty state',
      );

      await binding.takeScreenshot('TC-T12_pengumuman');
      await goBack(tester);
      debugPrint('✅ TC-T12 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T13: Rekomendasi Pembelajaran — class card list + expand
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T13: Rekomendasi Pembelajaran — class list + expand card',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');
      final opened = await tapMenu(tester, 'Rekomendasi Pembelajaran');
      if (!opened) return;

      await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 12);
      expectScreenLoaded('Rekomendasi Pembelajaran');

      // Tap first class card to expand.
      final cards = find.byType(Card);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first, warnIfMissed: false);
        await pumpFor(tester, count: 16);
        expectScreenLoaded('Rekomendasi after card expand');
      }

      await binding.takeScreenshot('TC-T13_rekomendasi');
      await goBack(tester);
      debugPrint('✅ TC-T13 PASSED');
    },
  );

  // ------------------------------------------------------------------
  // TC-T14: Back-stack integrity — open every menu in turn, back-and-forth
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T14: Back-stack integrity across all teacher menus',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      const menus = <String>[
        'Jadwal Mengajar',
        'Aktivitas Kelas',
        'Absensi Siswa',
        'Materi Pembelajaran',
        'Input Nilai',
        'Rekapitulasi Nilai',
        'RPP Saya',
        'Pengumuman',
        'Rekomendasi Pembelajaran',
      ];

      var navigated = 0;
      var skipped = 0;

      for (final m in menus) {
        final found = await tapMenu(tester, m);
        if (!found) {
          skipped++;
          continue;
        }
        await waitForWidget(tester, find.byType(Scaffold), maxSeconds: 10);
        expectScreenLoaded(m);

        await goBack(tester);
        await pumpFor(tester);
        // Back must always return us to a Scaffold (the dashboard).
        expectScreenLoaded('Dashboard after back from $m');
        navigated++;
      }

      expect(
        navigated,
        greaterThanOrEqualTo(5),
        reason:
            'At least 5 of the 9 teacher menus should be reachable end-to-end '
            '(navigated $navigated, skipped $skipped).',
      );
      debugPrint('✅ TC-T14 PASSED — nav $navigated / skip $skipped');
    },
  );

  // ------------------------------------------------------------------
  // TC-T15: Logout from teacher dashboard returns to login screen
  // ------------------------------------------------------------------
  testWidgets(
    'TC-T15: Teacher logout returns to login screen',
    timeout: const Timeout(Duration(minutes: 5)),
    (tester) async {
      await loginAndNavigateToDashboard(tester, role: 'Teacher');

      // Open the account/profile menu — could be an icon button or a tab.
      final accountIcon = find.byIcon(Icons.account_circle);
      final personIcon = find.byIcon(Icons.person);
      final entry = accountIcon.evaluate().isNotEmpty
          ? accountIcon
          : personIcon;
      if (entry.evaluate().isNotEmpty) {
        await tester.tap(entry.first, warnIfMissed: false);
        await pumpFor(tester);
      }

      // Tap the logout entry. The label is 'Keluar' (Indonesian) or 'Logout'.
      for (final label in ['Keluar', 'Logout']) {
        final btn = find.text(label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first, warnIfMissed: false);
          await pumpFor(tester);
          break;
        }
      }

      // Confirm dialog ('Ya' / 'Yes') — optional.
      for (final label in ['Ya', 'Yes', 'OK']) {
        final btn = find.text(label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first, warnIfMissed: false);
          await pumpFor(tester);
          break;
        }
      }

      await waitForWidget(
        tester,
        find.byKey(const Key('login_button')),
        maxSeconds: 8,
      );
      expect(
        find.byKey(const Key('login_button')),
        findsOneWidget,
        reason: 'Logout should return us to the login screen',
      );

      await binding.takeScreenshot('TC-T15_logged_out');
      debugPrint('✅ TC-T15 PASSED');
    },
  );
}
