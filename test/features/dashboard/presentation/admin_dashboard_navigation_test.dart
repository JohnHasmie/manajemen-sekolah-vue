// ignore_for_file: lines_longer_than_80_chars
/// Admin dashboard navigation flow tests.
///
/// Tests the full round-trip for EVERY admin menu item and quick action:
///   tap item → destination screen appears → back → Admin Dashboard restored.
///
/// Also tests deep navigation flows (2-3 levels) that mirror real admin usage:
///   Dashboard → Data Management → child screens → back back
///   Dashboard → Finance → Payment Type → back back
///   Dashboard → Grade Input → Class List → Grade Book → back back
///   Dashboard → School Settings → child → back back
///
/// Uses mock scaffold destinations — the goal is to verify navigation routing
/// and back-stack integrity, not to render real data screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sub-screen with optional child navigation items.
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

/// Admin Dashboard mock — all real quick actions + menu items.
Widget _buildAdminDashboard() {
  const primaryColor = Color(0xFF06B6D4);

  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
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
                      label: 'Data',
                      icon: Icons.folder_outlined,
                      color: primaryColor,
                      onTap: () => AppNavigator.push(
                        ctx,
                        _subScreen(
                          title: 'Data Management',
                          children: [
                            (label: 'Students', dest: 'Student Management'),
                            (label: 'Teachers', dest: 'Teacher Management'),
                            (label: 'Classrooms', dest: 'Classroom Management'),
                            (label: 'Subjects', dest: 'Subject Management'),
                          ],
                        ),
                      ),
                    ),
                    QuickActionButton(
                      label: 'Schedule',
                      icon: Icons.schedule_outlined,
                      color: primaryColor,
                      onTap: () => AppNavigator.push(
                        ctx,
                        _subScreen(
                          title: 'Schedule Management',
                          children: [
                            (label: 'Add Schedule', dest: 'Add Schedule Form'),
                            (
                              label: 'Edit Schedule',
                              dest: 'Edit Schedule Form',
                            ),
                          ],
                        ),
                      ),
                    ),
                    QuickActionButton(
                      label: 'Finance',
                      icon: Icons.account_balance_wallet_outlined,
                      color: primaryColor,
                      onTap: () => AppNavigator.push(
                        ctx,
                        _subScreen(
                          title: 'Finance Screen',
                          children: [
                            (
                              label: 'Payment Types',
                              dest: 'Payment Type Detail',
                            ),
                            (label: 'Generate Bills', dest: 'Bill Generation'),
                          ],
                        ),
                      ),
                    ),
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
                              label: 'New Announcement',
                              dest: 'Announcement Form',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Menu Items: Data Management ────────────────────────────────
                //
                MenuItemCard(
                  title: 'Manage Data',
                  icon: Icons.folder_shared_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Data Management',
                      children: [
                        (label: 'Students', dest: 'Student Management'),
                        (label: 'Teachers', dest: 'Teacher Management'),
                        (label: 'Classrooms', dest: 'Classroom Management'),
                        (label: 'Subjects', dest: 'Subject Management'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Teaching Schedule',
                  icon: Icons.schedule_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Schedule Management',
                      children: [
                        (label: 'Add Schedule', dest: 'Add Schedule Form'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Input Grades',
                  icon: Icons.edit_note_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Grade Input',
                      children: [
                        (label: 'Kelas 7A', dest: 'Grade Book 7A'),
                        (label: 'Kelas 8B', dest: 'Grade Book 8B'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Announcements',
                  icon: Icons.announcement_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Announcements Screen',
                      children: [
                        (label: 'New Announcement', dest: 'Announcement Form'),
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
                      title: 'Class Activities Screen',
                      children: [
                        (
                          label: 'Activity Detail',
                          dest: 'Activity Detail View',
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Attendance Report',
                  icon: Icons.check_circle_outline,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Attendance Report Screen',
                      children: [
                        (label: 'Export Report', dest: 'Export Dialog'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Lesson Plans',
                  icon: Icons.description_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Lesson Plans Screen',
                      children: [
                        (
                          label: 'Lesson Plan Detail',
                          dest: 'Lesson Plan Detail View',
                        ),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Student Report Card',
                  icon: Icons.assignment_turned_in_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Report Card Screen',
                      children: [
                        (label: 'View Report Card', dest: 'Report Card View'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'Finance',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'Finance Screen',
                      children: [
                        (label: 'Payment Types', dest: 'Payment Type Detail'),
                        (label: 'Generate Bills', dest: 'Bill Generation'),
                      ],
                    ),
                  ),
                ),
                MenuItemCard(
                  title: 'School Settings',
                  icon: Icons.settings_applications,
                  onTap: () => AppNavigator.push(
                    ctx,
                    _subScreen(
                      title: 'School Settings Screen',
                      children: [
                        (label: 'Time Settings', dest: 'Time Settings View'),
                        (label: 'Academic Year', dest: 'Academic Year View'),
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
// Typed finders — avoid ambiguity when same text appears in quick action + menu
// ---------------------------------------------------------------------------

/// Scroll to and tap a [MenuItemCard] by its title.
Future<void> _tapMenu(WidgetTester tester, String title) async {
  final finder = find.widgetWithText(MenuItemCard, title);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scroll to and tap a [QuickActionButton] by its label.
Future<void> _tapQuick(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(QuickActionButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Verify we're on [screen], then tap BackButton and verify we return to
// Dashboard.
Future<void> _assertScreenAndBack(
  WidgetTester tester,
  String screen,
  String dashboardTitle,
) async {
  expect(find.text(screen), findsOneWidget, reason: 'Should be on "$screen"');
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(
    find.text(dashboardTitle),
    findsOneWidget,
    reason: 'Should return to "$dashboardTitle"',
  );
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // Quick Actions
  // =========================================================================
  group('Admin Dashboard — Quick Actions navigation', () {
    testWidgets('Data → Data Management → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapQuick(tester, 'Data');
      await _assertScreenAndBack(tester, 'Data Management', 'Admin Dashboard');
    });

    testWidgets('Schedule → Schedule Management → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapQuick(tester, 'Schedule');
      await _assertScreenAndBack(
        tester,
        'Schedule Management',
        'Admin Dashboard',
      );
    });

    testWidgets('Finance (quick action) → Finance Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapQuick(tester, 'Finance');
      await _assertScreenAndBack(tester, 'Finance Screen', 'Admin Dashboard');
    });

    testWidgets('Announcements (quick action) → Announcements Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapQuick(tester, 'Announcements');
      await _assertScreenAndBack(
        tester,
        'Announcements Screen',
        'Admin Dashboard',
      );
    });
  });

  // =========================================================================
  // Menu Items — single-level navigation
  // =========================================================================
  group('Admin Dashboard — Menu Items single-level navigation', () {
    testWidgets('Manage Data → Data Management → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Manage Data');
      await _assertScreenAndBack(tester, 'Data Management', 'Admin Dashboard');
    });

    testWidgets('Teaching Schedule → Schedule Management → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Teaching Schedule');
      await _assertScreenAndBack(
        tester,
        'Schedule Management',
        'Admin Dashboard',
      );
    });

    testWidgets('Input Grades → Grade Input → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Input Grades');
      await _assertScreenAndBack(tester, 'Grade Input', 'Admin Dashboard');
    });

    testWidgets('Announcements (menu) → Announcements Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Announcements');
      await _assertScreenAndBack(
        tester,
        'Announcements Screen',
        'Admin Dashboard',
      );
    });

    testWidgets('Class Activities → Class Activities Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Class Activities');
      await _assertScreenAndBack(
        tester,
        'Class Activities Screen',
        'Admin Dashboard',
      );
    });

    testWidgets('Attendance Report → Attendance Report Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Attendance Report');
      await _assertScreenAndBack(
        tester,
        'Attendance Report Screen',
        'Admin Dashboard',
      );
    });

    testWidgets('Lesson Plans → Lesson Plans Screen → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Lesson Plans');
      await _assertScreenAndBack(
        tester,
        'Lesson Plans Screen',
        'Admin Dashboard',
      );
    });

    testWidgets('Student Report Card → Report Card Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Student Report Card');
      await _assertScreenAndBack(
        tester,
        'Report Card Screen',
        'Admin Dashboard',
      );
    });

    testWidgets('Finance (menu) → Finance Screen → back', (tester) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'Finance');
      await _assertScreenAndBack(tester, 'Finance Screen', 'Admin Dashboard');
    });

    testWidgets('School Settings → School Settings Screen → back', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());
      await _tapMenu(tester, 'School Settings');
      await _assertScreenAndBack(
        tester,
        'School Settings Screen',
        'Admin Dashboard',
      );
    });
  });

  // =========================================================================
  // Deep: Data Management → children → back all to Dashboard
  // =========================================================================
  group('Admin Dashboard — Deep: Data Management', () {
    testWidgets(
      'Dashboard → Data Mgmt → Student Mgmt → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Manage Data');
        expect(find.text('Data Management'), findsOneWidget);

        await tester.tap(find.text('Students'));
        await tester.pumpAndSettle();
        expect(find.text('Student Management'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Data Management'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'visits all 4 Data Mgmt children and always returns to Dashboard',
      (tester) async {
        for (final child in [
          ('Students', 'Student Management'),
          ('Teachers', 'Teacher Management'),
          ('Classrooms', 'Classroom Management'),
          ('Subjects', 'Subject Management'),
        ]) {
          await tester.pumpWidget(_buildAdminDashboard());

          await _tapMenu(tester, 'Manage Data');
          await tester.tap(find.text(child.$1));
          await tester.pumpAndSettle();
          expect(find.text(child.$2), findsOneWidget);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Admin Dashboard'), findsOneWidget);
        }
      },
    );
  });

  // =========================================================================
  // Deep: Grade Input → class → grade book → back all
  // =========================================================================
  group('Admin Dashboard — Deep: Grade Input', () {
    testWidgets(
      'Dashboard → Grade Input → Kelas 7A → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Input Grades');
        expect(find.text('Grade Input'), findsOneWidget);

        await tester.tap(find.text('Kelas 7A'));
        await tester.pumpAndSettle();
        expect(find.text('Grade Book 7A'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Grade Input'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Grade Input → Kelas 8B → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Input Grades');
        await tester.tap(find.text('Kelas 8B'));
        await tester.pumpAndSettle();
        expect(find.text('Grade Book 8B'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: Finance → child screens → back all
  // =========================================================================
  group('Admin Dashboard — Deep: Finance', () {
    testWidgets(
      'Dashboard → Finance → Payment Type → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Finance');
        expect(find.text('Finance Screen'), findsOneWidget);

        await tester.tap(find.text('Payment Types'));
        await tester.pumpAndSettle();
        expect(find.text('Payment Type Detail'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → Finance → Generate Bills → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Finance');
        await tester.tap(find.text('Generate Bills'));
        await tester.pumpAndSettle();
        expect(find.text('Bill Generation'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: School Settings → children → back all
  // =========================================================================
  group('Admin Dashboard — Deep: School Settings', () {
    testWidgets(
      'Dashboard → School Settings → Time Settings → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'School Settings');
        await tester.tap(find.text('Time Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Time Settings View'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard → School Settings → Academic Year → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'School Settings');
        await tester.tap(find.text('Academic Year'));
        await tester.pumpAndSettle();
        expect(find.text('Academic Year View'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Deep: Attendance Report → export → back all
  // =========================================================================
  group('Admin Dashboard — Deep: Attendance Report', () {
    testWidgets(
      'Dashboard → Attendance Report → Export → back → back → Dashboard',
      (tester) async {
        await tester.pumpWidget(_buildAdminDashboard());

        await _tapMenu(tester, 'Attendance Report');
        await tester.tap(find.text('Export Report'));
        await tester.pumpAndSettle();
        expect(find.text('Export Dialog'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Admin Dashboard'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // Back-stack isolation
  // =========================================================================
  group('Admin Dashboard — Back-stack isolation between menus', () {
    testWidgets('Grade Input and Finance stacks are independent', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboard());

      // Visit Grade Input → 7A
      await _tapMenu(tester, 'Input Grades');
      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Grade Book 7A'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Admin Dashboard'), findsOneWidget);

      // Visit Finance → Payment Types — no Grade residue
      await _tapMenu(tester, 'Finance');
      await tester.tap(find.text('Payment Types'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Type Detail'), findsOneWidget);
      expect(find.text('Grade Book 7A'), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('all menu items cycle without stack pollution', (tester) async {
      final menus = [
        ('Manage Data', 'Data Management'),
        ('Teaching Schedule', 'Schedule Management'),
        ('Input Grades', 'Grade Input'),
        ('Announcements', 'Announcements Screen'),
        ('Class Activities', 'Class Activities Screen'),
        ('Attendance Report', 'Attendance Report Screen'),
        ('Lesson Plans', 'Lesson Plans Screen'),
        ('Student Report Card', 'Report Card Screen'),
        ('Finance', 'Finance Screen'),
        ('School Settings', 'School Settings Screen'),
      ];

      for (final (title, screen) in menus) {
        await tester.pumpWidget(_buildAdminDashboard());
        await _tapMenu(tester, title);
        expect(
          find.text(screen),
          findsOneWidget,
          reason: '$title should open $screen',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          find.text('Admin Dashboard'),
          findsOneWidget,
          reason: 'Back from $screen should restore Admin Dashboard',
        );
      }
    });
  });
}
