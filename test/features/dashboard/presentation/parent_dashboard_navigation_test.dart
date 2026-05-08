// ignore_for_file: lines_longer_than_80_chars
/// Parent (Wali) dashboard navigation flow tests.
///
/// Tests every quick action and menu item for the parent role:
///   tap → destination → back → Parent Dashboard restored.
///
/// Deep flows:
///   Dashboard → Announcements → Detail → back back
///   Dashboard → Class Activities → Detail → back back
///   Dashboard → Grades → Subject Detail → back back
///   Dashboard → Presence → Student Selector → Attendance View → back back back
///   Dashboard → Billing → Bill Detail / History → back back
///   Dashboard → eReport Card → Semester Detail → back back
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _subScreen({
  required String title,
  List<({String label, String dest})> children = const [],
  List<({String label, Widget screen})> richChildren = const [],
}) {
  return Builder(
    builder: (ctx) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          children: [
            ...children.map(
              (c) => ListTile(
                title: Text(c.label),
                onTap: () => AppNavigator.push(
                  ctx,
                  Scaffold(
                    appBar: AppBar(title: Text(c.dest)),
                    body: Text('${c.dest} body'),
                  ),
                ),
              ),
            ),
            ...richChildren.map(
              (c) => ListTile(
                title: Text(c.label),
                onTap: () => AppNavigator.push(ctx, c.screen),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildParentDashboard() {
  const primaryColor = Color(0xFF9333EA);

  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Parent Dashboard')),
      body: Builder(
        builder: (ctx) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Quick Actions ──────────────────────────────────────────────
                //
                Row(
                  children: [
                    QuickActionButton(
                      label: 'Announcements',
                      icon: Icons.announcement_outlined,
                      color: primaryColor,
                      onTap: () => AppNavigator.push(
                        ctx,
                        _subScreen(
                          title: 'Announcements Screen',
                          children: [
                            (
                              label: 'Pengumuman PPDB',
                              dest: 'PPDB Announcement Detail',
                            ),
                            (
                              label: 'Libur Nasional',
                              dest: 'Holiday Announcement Detail',
                            ),
                          ],
                        ),
                      ),
                    ),
                    QuickActionButton(
                      label: 'Billing',
                      icon: Icons.account_balance_wallet_outlined,
                      color: primaryColor,
                      onTap: () => AppNavigator.push(
                        ctx,
                        _subScreen(
                          title: 'Parent Billing Screen',
                          children: [
                            (
                              label: 'SPP Bulan Ini',
                              dest: 'Monthly SPP Detail',
                            ),
                            (
                              label: 'Riwayat Pembayaran',
                              dest: 'Payment History View',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Menu Items ─────────────────────────────────────────────────
                //
                MenuItemCard(
                  title: 'Announcements',
                  icon: Icons.announcement_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Announcements Screen',
                      children: [
                        (
                          label: 'Pengumuman PPDB',
                          dest: 'PPDB Announcement Detail',
                        ),
                        (
                          label: 'Libur Nasional',
                          dest: 'Holiday Announcement Detail',
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Class Activities',
                  icon: Icons.local_activity_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Class Activities Parent Screen',
                      children: [
                        (
                          label: 'Kegiatan Hari Ini',
                          dest: 'Today Activity Detail',
                        ),
                        (
                          label: 'Kegiatan Kemarin',
                          dest: 'Yesterday Activity Detail',
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Grades',
                  icon: Icons.grade_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Parent Grades Screen',
                      children: [
                        (label: 'Matematika', dest: 'Math Grade Detail'),
                        (
                          label: 'Bahasa Indonesia',
                          dest: 'Bahasa Grade Detail',
                        ),
                        (label: 'IPA', dest: 'IPA Grade Detail'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Presence',
                  icon: Icons.check_circle_outline,
                  onTap: () => AppNavigator.push(
                    ctx,
                    // Parent may have multiple children → student selector
                    _subScreen(
                      title: 'Select Student Screen',
                      children: [
                        (label: 'Ahmad Fauzi', dest: 'Ahmad Attendance View'),
                      ],
                      richChildren: [
                        (
                          label: 'Siti Fatimah',
                          screen: Builder(
                            builder: (ctx2) {
                              return Scaffold(
                                appBar: AppBar(
                                  title: const Text('Siti Attendance Screen'),
                                ),
                                body: ListTile(
                                  title: const Text('Detail Kehadiran'),
                                  onTap: () => AppNavigator.push(
                                    ctx2,
                                    Scaffold(
                                      appBar: AppBar(
                                        title: const Text(
                                          'Attendance Detail View',
                                        ),
                                      ),
                                      body: const Text(
                                        'Attendance detail data',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Billing',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Parent Billing Screen',
                      children: [
                        (label: 'SPP Bulan Ini', dest: 'Monthly SPP Detail'),
                        (
                          label: 'Riwayat Pembayaran',
                          dest: 'Payment History View',
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'eReport Card',
                  icon: Icons.assignment_turned_in_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Parent Report Card Screen',
                      children: [
                        (label: 'Semester 1', dest: 'Semester 1 Report View'),
                        (label: 'Semester 2', dest: 'Semester 2 Report View'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Typed helpers
// ---------------------------------------------------------------------------

Future<void> _tapMenu(WidgetTester tester, String title) async {
  final finder = find.widgetWithText(MenuItemCard, title);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapQuick(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(QuickActionButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _assertScreenAndBack(
  WidgetTester tester,
  String screen,
  String dashboard,
) async {
  expect(find.text(screen), findsOneWidget, reason: 'Should be on "$screen"');
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(
    find.text(dashboard),
    findsOneWidget,
    reason: 'Should return to "$dashboard"',
  );
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // Quick Actions
  // =========================================================================
  group('Parent Dashboard — Quick Actions navigation', () {
    testWidgets('Announcements (quick) → Announcements Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapQuick(tester, 'Announcements');
      await _assertScreenAndBack(
        tester,
        'Announcements Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('Billing (quick) → Parent Billing Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapQuick(tester, 'Billing');
      await _assertScreenAndBack(
        tester,
        'Parent Billing Screen',
        'Parent Dashboard',
      );
    });
  });

  // =========================================================================
  // Menu Items — single-level
  // =========================================================================
  group('Parent Dashboard — Menu Items single-level navigation', () {
    testWidgets('Announcements (menu) → Announcements Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'Announcements');
      await _assertScreenAndBack(
        tester,
        'Announcements Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('Class Activities → Class Activities Parent Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'Class Activities');
      await _assertScreenAndBack(
        tester,
        'Class Activities Parent Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('Grades → Parent Grades Screen → back', (tester) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'Grades');
      await _assertScreenAndBack(
        tester,
        'Parent Grades Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('Presence → Select Student Screen → back', (tester) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'Presence');
      await _assertScreenAndBack(
        tester,
        'Select Student Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('Billing (menu) → Parent Billing Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'Billing');
      await _assertScreenAndBack(
        tester,
        'Parent Billing Screen',
        'Parent Dashboard',
      );
    });

    testWidgets('eReport Card → Parent Report Card Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());
      await _tapMenu(tester, 'eReport Card');
      await _assertScreenAndBack(
        tester,
        'Parent Report Card Screen',
        'Parent Dashboard',
      );
    });
  });

  // =========================================================================
  // Deep: Announcements → detail
  // =========================================================================
  group('Parent Dashboard — Deep: Announcements', () {
    testWidgets(
      'Dashboard → Announcements → PPDB Detail → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Announcements');
        expect(find.text('Announcements Screen'), findsOneWidget);

        await tester.tap(find.text('Pengumuman PPDB'));
        await tester.pumpAndSettle();
        expect(find.text('PPDB Announcement Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Announcements Screen'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Announcements → Holiday Detail → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Announcements');
        await tester.tap(find.text('Libur Nasional'));
        await tester.pumpAndSettle();
        expect(find.text('Holiday Announcement Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: Class Activities → activity detail
  // =========================================================================
  group('Parent Dashboard — Deep: Class Activities', () {
    testWidgets(
      'Dashboard → Class Activities → Today → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Class Activities');
        expect(find.text('Class Activities Parent Screen'), findsOneWidget);

        await tester.tap(find.text('Kegiatan Hari Ini'));
        await tester.pumpAndSettle();
        expect(find.text('Today Activity Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Class Activities Parent Screen'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Class Activities → Yesterday → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Class Activities');
        await tester.tap(find.text('Kegiatan Kemarin'));
        await tester.pumpAndSettle();
        expect(find.text('Yesterday Activity Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: Grades → subject detail
  // =========================================================================
  group('Parent Dashboard — Deep: Grades', () {
    testWidgets('Dashboard → Grades → Matematika → back → back → Dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());

      await _tapMenu(tester, 'Grades');
      await tester.tap(find.text('Matematika'));
      await tester.pumpAndSettle();
      expect(find.text('Math Grade Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Parent Grades Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Parent Dashboard'), findsOneWidget);
    });

    testWidgets(
      'Dashboard → Grades → Bahasa Indonesia → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Grades');
        await tester.tap(find.text('Bahasa Indonesia'));
        await tester.pumpAndSettle();
        expect(find.text('Bahasa Grade Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets('Dashboard → Grades → IPA → back → back → Dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(_buildParentDashboard());

      await _tapMenu(tester, 'Grades');
      await tester.tap(find.text('IPA'));
      await tester.pumpAndSettle();
      expect(find.text('IPA Grade Detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Parent Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Presence → student selector → attendance → optional detail (3 levels)
  // =========================================================================
  group('Parent Dashboard — Deep: Presence', () {
    testWidgets(
      'Dashboard → Presence → Ahmad → Attendance → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        // Level 1: Dashboard → Select Student
        await _tapMenu(tester, 'Presence');
        expect(find.text('Select Student Screen'), findsOneWidget);

        // Level 2: Select Student → Ahmad Attendance
        await tester.tap(find.text('Ahmad Fauzi'));
        await tester.pumpAndSettle();
        expect(find.text('Ahmad Attendance View'), findsOneWidget);

        // Back to Select Student
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Select Student Screen'), findsOneWidget);

        // Back to Dashboard
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Presence → Siti → Attendance → Detail Kehadiran → back → back → back → Dashboard (3 levels)',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        // Level 1
        await _tapMenu(tester, 'Presence');
        expect(find.text('Select Student Screen'), findsOneWidget);

        // Level 2
        await tester.tap(find.text('Siti Fatimah'));
        await tester.pumpAndSettle();
        expect(find.text('Siti Attendance Screen'), findsOneWidget);

        // Level 3
        await tester.tap(find.text('Detail Kehadiran'));
        await tester.pumpAndSettle();
        expect(find.text('Attendance Detail View'), findsOneWidget);
        expect(find.text('Attendance detail data'), findsOneWidget);

        // Back to level 2
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Siti Attendance Screen'), findsOneWidget);
        expect(find.text('Attendance Detail View'), findsNothing);

        // Back to level 1
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Select Student Screen'), findsOneWidget);

        // Back to Dashboard
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: Billing → bill detail / payment history
  // =========================================================================
  group('Parent Dashboard — Deep: Billing', () {
    testWidgets(
      'Dashboard → Billing → SPP Bulan Ini → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Billing');
        expect(find.text('Parent Billing Screen'), findsOneWidget);

        await tester.tap(find.text('SPP Bulan Ini'));
        await tester.pumpAndSettle();
        expect(find.text('Monthly SPP Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Billing Screen'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Billing → Riwayat Pembayaran → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'Billing');
        await tester.tap(find.text('Riwayat Pembayaran'));
        await tester.pumpAndSettle();
        expect(find.text('Payment History View'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: eReport Card → semester
  // =========================================================================
  group('Parent Dashboard — Deep: eReport Card', () {
    testWidgets(
      'Dashboard → eReport Card → Semester 1 → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'eReport Card');
        await tester.tap(find.text('Semester 1'));
        await tester.pumpAndSettle();
        expect(find.text('Semester 1 Report View'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Report Card Screen'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → eReport Card → Semester 2 → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildParentDashboard());

        await _tapMenu(tester, 'eReport Card');
        await tester.tap(find.text('Semester 2'));
        await tester.pumpAndSettle();
        expect(find.text('Semester 2 Report View'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Parent Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Back-stack isolation
  // =========================================================================
  group('Parent Dashboard — Back-stack isolation', () {
    testWidgets('Grades and Billing stacks do not interfere', (tester) async {
      await tester.pumpWidget(_buildParentDashboard());

      // Visit Grades → Matematika → pop
      await _tapMenu(tester, 'Grades');
      await tester.tap(find.text('Matematika'));
      await tester.pumpAndSettle();
      expect(find.text('Math Grade Detail'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Parent Dashboard'), findsOneWidget);

      // Visit Billing → SPP — no Grades residue
      await _tapMenu(tester, 'Billing');
      await tester.tap(find.text('SPP Bulan Ini'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly SPP Detail'), findsOneWidget);
      expect(find.text('Math Grade Detail'), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Parent Dashboard'), findsOneWidget);
    });

    testWidgets('all 6 menu items cycle without stack pollution', (
      tester,
    ) async {
      final menus = [
        ('Announcements', 'Announcements Screen'),
        ('Class Activities', 'Class Activities Parent Screen'),
        ('Grades', 'Parent Grades Screen'),
        ('Presence', 'Select Student Screen'),
        ('Billing', 'Parent Billing Screen'),
        ('eReport Card', 'Parent Report Card Screen'),
      ];

      for (final (title, screen) in menus) {
        await tester.pumpWidget(_buildParentDashboard());
        await _tapMenu(tester, title);
        expect(
          find.text(screen),
          findsOneWidget,
          reason: '$title should open $screen',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          find.text('Parent Dashboard'),
          findsOneWidget,
          reason: 'Back from $screen should restore Parent Dashboard',
        );
      }
    });
  });
}
