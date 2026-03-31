/// Teacher (Guru) dashboard navigation flow tests.
///
/// Tests every quick action and menu item for the teacher role:
///   tap → destination → back → Teacher Dashboard restored.
///
/// Deep flows:
///   Dashboard → Teaching Schedule → Day View → back back
///   Dashboard → Attendance → Class List → Student List → back back back
///   Dashboard → Grade Input → Class List → Grade Book → back back
///   Dashboard → Grade Recap → Class → Subject → Grade Table → back back back
///   Dashboard → Learning Recommendation → Class Card → back back
///   Dashboard → Lesson Plans → Plan Detail → back back
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
  return Builder(builder: (ctx) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          ...children.map((c) => ListTile(
                title: Text(c.label),
                onTap: () => AppNavigator.push(
                  ctx,
                  Scaffold(
                    appBar: AppBar(title: Text(c.dest)),
                    body: Text('${c.dest} body'),
                  ),
                ),
              )),
          ...richChildren.map((c) => ListTile(
                title: Text(c.label),
                onTap: () => AppNavigator.push(ctx, c.screen),
              )),
        ],
      ),
    );
  });
}

Widget _buildTeacherDashboard() {
  const primaryColor = Color(0xFF16A34A);

  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: Builder(builder: (ctx) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Quick Actions ──────────────────────────────────────────────
              Row(children: [
                QuickActionButton(
                  label: 'Schedule',
                  icon: Icons.schedule_outlined,
                  color: primaryColor,
                  onTap: () => AppNavigator.push(ctx,
                      _subScreen(title: 'Teaching Schedule Screen', children: [
                        (label: 'Monday', dest: 'Monday Schedule'),
                        (label: 'Tuesday', dest: 'Tuesday Schedule'),
                      ])),
                ),
                QuickActionButton(
                  label: 'Attendance',
                  icon: Icons.how_to_reg_outlined,
                  color: primaryColor,
                  onTap: () => AppNavigator.push(ctx,
                      _subScreen(title: 'Student Attendance Screen', children: [
                        (label: 'Kelas 7A', dest: 'Attendance 7A'),
                        (label: 'Kelas 8B', dest: 'Attendance 8B'),
                      ])),
                ),
                QuickActionButton(
                  label: 'Activity',
                  icon: Icons.local_activity_outlined,
                  color: primaryColor,
                  onTap: () => AppNavigator.push(ctx,
                      _subScreen(title: 'Class Activities Screen', children: [
                        (label: 'New Activity', dest: 'Activity Form'),
                      ])),
                ),
                QuickActionButton(
                  label: 'Input Grades',
                  icon: Icons.edit_note_outlined,
                  color: primaryColor,
                  onTap: () => AppNavigator.push(ctx,
                      _subScreen(title: 'Grade Input Screen', children: [
                        (label: 'Kelas 7A', dest: 'Grade Book 7A'),
                        (label: 'Kelas 8B', dest: 'Grade Book 8B'),
                      ])),
                ),
              ]),

              // ── Menu Items: Teaching ───────────────────────────────────────
              MenuItemCard(
                title: 'Teaching Schedule',
                icon: Icons.schedule_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Teaching Schedule Screen', children: [
                      (label: 'Monday', dest: 'Monday Schedule'),
                      (label: 'Tuesday', dest: 'Tuesday Schedule'),
                    ])),
              ),
              MenuItemCard(
                title: 'Class Activities',
                icon: Icons.local_activity_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Class Activities Screen', children: [
                      (label: 'New Activity', dest: 'Activity Form'),
                      (label: 'Activity List', dest: 'Activity List View'),
                    ])),
              ),
              MenuItemCard(
                title: 'Student Attendance',
                icon: Icons.check_circle_outline,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Student Attendance Screen', children: [
                      (label: 'Kelas 7A', dest: 'Attendance 7A'),
                      (label: 'Kelas 8B', dest: 'Attendance 8B'),
                    ])),
              ),
              MenuItemCard(
                title: 'Learning Materials',
                icon: Icons.book_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Learning Materials Screen', children: [
                      (label: 'Upload Material', dest: 'Material Upload Form'),
                      (label: 'Material List', dest: 'Material List View'),
                    ])),
              ),

              // ── Menu Items: Assessment Planning ────────────────────────────
              MenuItemCard(
                title: 'Input Grades',
                icon: Icons.edit_note_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Grade Input Screen', children: [
                      (label: 'Kelas 7A', dest: 'Grade Book 7A'),
                      (label: 'Kelas 8B', dest: 'Grade Book 8B'),
                    ])),
              ),
              MenuItemCard(
                title: 'Grade Recap',
                icon: Icons.assessment_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(
                        title: 'Grade Recap Screen',
                        children: [
                          (label: 'Kelas 7A', dest: 'Subject List 7A'),
                        ],
                        richChildren: [
                          (
                            label: 'Kelas 8B',
                            screen: Builder(builder: (ctx2) {
                              return Scaffold(
                                appBar: AppBar(
                                    title: const Text('Subject List 8B')),
                                body: ListTile(
                                  title: const Text('Matematika'),
                                  onTap: () => AppNavigator.push(
                                    ctx2,
                                    Scaffold(
                                      appBar: AppBar(
                                          title: const Text('Grade Table 8B')),
                                      body: const Text('Grade table content'),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ])),
              ),
              MenuItemCard(
                title: 'Report Card',
                icon: Icons.contact_page_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Report Card Screen', children: [
                      (label: 'View Report', dest: 'Report Card Detail'),
                    ])),
              ),
              MenuItemCard(
                title: 'My Lesson Plans',
                icon: Icons.description_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Lesson Plans Screen', children: [
                      (label: 'RPP Matematika', dest: 'Lesson Plan Detail View'),
                      (label: 'Create RPP', dest: 'Lesson Plan Form View'),
                    ])),
              ),
              MenuItemCard(
                title: 'Announcements',
                icon: Icons.announcement_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Announcements Screen', children: [
                      (label: 'Detail Pengumuman', dest: 'Announcement Detail View'),
                    ])),
              ),
              MenuItemCard(
                title: 'Learning Recommendation',
                icon: Icons.auto_awesome_outlined,
                onTap: () => AppNavigator.push(ctx,
                    _subScreen(title: 'Learning Recommendation Screen', children: [
                      (label: 'Kelas 7A', dest: 'Recommendation 7A View'),
                      (label: 'Kelas 8B', dest: 'Recommendation 8B View'),
                    ])),
              ),
            ],
          ),
        );
      }),
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
    WidgetTester tester, String screen, String dashboard) async {
  expect(find.text(screen), findsOneWidget,
      reason: 'Should be on "$screen"');
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(find.text(dashboard), findsOneWidget,
      reason: 'Should return to "$dashboard"');
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // Quick Actions
  // =========================================================================
  group('Teacher Dashboard — Quick Actions navigation', () {
    testWidgets('Schedule → Teaching Schedule Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapQuick(tester, 'Schedule');
      await _assertScreenAndBack(tester, 'Teaching Schedule Screen', 'Teacher Dashboard');
    });

    testWidgets('Attendance → Student Attendance Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapQuick(tester, 'Attendance');
      await _assertScreenAndBack(tester, 'Student Attendance Screen', 'Teacher Dashboard');
    });

    testWidgets('Activity → Class Activities Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapQuick(tester, 'Activity');
      await _assertScreenAndBack(tester, 'Class Activities Screen', 'Teacher Dashboard');
    });

    testWidgets('Input Grades (quick action) → Grade Input Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapQuick(tester, 'Input Grades');
      await _assertScreenAndBack(tester, 'Grade Input Screen', 'Teacher Dashboard');
    });
  });

  // =========================================================================
  // Menu Items — single-level
  // =========================================================================
  group('Teacher Dashboard — Menu Items single-level navigation', () {
    testWidgets('Teaching Schedule (menu) → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Teaching Schedule');
      await _assertScreenAndBack(tester, 'Teaching Schedule Screen', 'Teacher Dashboard');
    });

    testWidgets('Class Activities (menu) → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Class Activities');
      await _assertScreenAndBack(tester, 'Class Activities Screen', 'Teacher Dashboard');
    });

    testWidgets('Student Attendance (menu) → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Student Attendance');
      await _assertScreenAndBack(tester, 'Student Attendance Screen', 'Teacher Dashboard');
    });

    testWidgets('Learning Materials → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Learning Materials');
      await _assertScreenAndBack(tester, 'Learning Materials Screen', 'Teacher Dashboard');
    });

    testWidgets('Input Grades (menu) → Grade Input Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Input Grades');
      await _assertScreenAndBack(tester, 'Grade Input Screen', 'Teacher Dashboard');
    });

    testWidgets('Grade Recap → Grade Recap Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Grade Recap');
      await _assertScreenAndBack(tester, 'Grade Recap Screen', 'Teacher Dashboard');
    });

    testWidgets('Report Card → Report Card Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Report Card');
      await _assertScreenAndBack(tester, 'Report Card Screen', 'Teacher Dashboard');
    });

    testWidgets('My Lesson Plans → Lesson Plans Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'My Lesson Plans');
      await _assertScreenAndBack(tester, 'Lesson Plans Screen', 'Teacher Dashboard');
    });

    testWidgets('Announcements (menu) → Announcements Screen → back', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Announcements');
      await _assertScreenAndBack(tester, 'Announcements Screen', 'Teacher Dashboard');
    });

    testWidgets('Learning Recommendation → Learning Recommendation Screen → back',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());
      await _tapMenu(tester, 'Learning Recommendation');
      await _assertScreenAndBack(
          tester, 'Learning Recommendation Screen', 'Teacher Dashboard');
    });
  });

  // =========================================================================
  // Deep: Teaching Schedule → day view
  // =========================================================================
  group('Teacher Dashboard — Deep: Teaching Schedule', () {
    testWidgets('Dashboard → Schedule → Monday → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapQuick(tester, 'Schedule');
      expect(find.text('Teaching Schedule Screen'), findsOneWidget);

      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      expect(find.text('Monday Schedule'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teaching Schedule Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Schedule → Tuesday → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapQuick(tester, 'Schedule');
      await tester.tap(find.text('Tuesday'));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday Schedule'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Student Attendance → class → attendance list
  // =========================================================================
  group('Teacher Dashboard — Deep: Student Attendance', () {
    testWidgets('Dashboard → Attendance → 7A → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapQuick(tester, 'Attendance');
      expect(find.text('Student Attendance Screen'), findsOneWidget);

      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance 7A'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Student Attendance Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Attendance → 8B → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapQuick(tester, 'Attendance');
      await tester.tap(find.text('Kelas 8B'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance 8B'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Grade Input → class → grade book
  // =========================================================================
  group('Teacher Dashboard — Deep: Grade Input', () {
    testWidgets('Dashboard → Grade Input → 7A → Grade Book → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Input Grades');
      expect(find.text('Grade Input Screen'), findsOneWidget);

      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Grade Book 7A'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Grade Input Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Grade Input → 8B → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Input Grades');
      await tester.tap(find.text('Kelas 8B'));
      await tester.pumpAndSettle();
      expect(find.text('Grade Book 8B'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Grade Recap wizard — 3 levels: class → subject → table
  // =========================================================================
  group('Teacher Dashboard — Deep: Grade Recap wizard (3 levels)', () {
    testWidgets(
        'Dashboard → Grade Recap → 8B → Matematika → Grade Table → back back back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      // Level 1: to Grade Recap
      await _tapMenu(tester, 'Grade Recap');
      expect(find.text('Grade Recap Screen'), findsOneWidget);

      // Level 2: select class → subject list
      await tester.tap(find.text('Kelas 8B'));
      await tester.pumpAndSettle();
      expect(find.text('Subject List 8B'), findsOneWidget);

      // Level 3: select subject → grade table
      await tester.tap(find.text('Matematika'));
      await tester.pumpAndSettle();
      expect(find.text('Grade Table 8B'), findsOneWidget);
      expect(find.text('Grade table content'), findsOneWidget);

      // Back to subject list
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Subject List 8B'), findsOneWidget);
      expect(find.text('Grade Table 8B'), findsNothing);

      // Back to grade recap
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Grade Recap Screen'), findsOneWidget);

      // Back to dashboard
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Grade Recap → 7A → Subject List → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Grade Recap');
      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Subject List 7A'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Lesson Plans → plan detail/form
  // =========================================================================
  group('Teacher Dashboard — Deep: Lesson Plans', () {
    testWidgets('Dashboard → Lesson Plans → RPP Detail → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'My Lesson Plans');
      await tester.tap(find.text('RPP Matematika'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson Plan Detail View'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Lesson Plans Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Lesson Plans → Create RPP → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'My Lesson Plans');
      await tester.tap(find.text('Create RPP'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson Plan Form View'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Learning Recommendation → class card
  // =========================================================================
  group('Teacher Dashboard — Deep: Learning Recommendation', () {
    testWidgets('Dashboard → Recommendation → 7A → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Learning Recommendation');
      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Recommendation 7A View'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Recommendation → 8B → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Learning Recommendation');
      await tester.tap(find.text('Kelas 8B'));
      await tester.pumpAndSettle();
      expect(find.text('Recommendation 8B View'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Deep: Learning Materials
  // =========================================================================
  group('Teacher Dashboard — Deep: Learning Materials', () {
    testWidgets('Dashboard → Materials → Upload → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Learning Materials');
      await tester.tap(find.text('Upload Material'));
      await tester.pumpAndSettle();
      expect(find.text('Material Upload Form'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard → Materials → Material List → back → back → Dashboard',
        (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      await _tapMenu(tester, 'Learning Materials');
      await tester.tap(find.text('Material List'));
      await tester.pumpAndSettle();
      expect(find.text('Material List View'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });
  });

  // =========================================================================
  // Back-stack isolation
  // =========================================================================
  group('Teacher Dashboard — Back-stack isolation', () {
    testWidgets('Attendance and Grade Input stacks are independent', (tester) async {
      await tester.pumpWidget(_buildTeacherDashboard());

      // Visit Attendance → 7A → pop back to Dashboard
      await _tapQuick(tester, 'Attendance');
      await tester.tap(find.text('Kelas 7A'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance 7A'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);

      // Visit Grade Input → 8B — no residue from Attendance
      await _tapMenu(tester, 'Input Grades');
      await tester.tap(find.text('Kelas 8B'));
      await tester.pumpAndSettle();
      expect(find.text('Grade Book 8B'), findsOneWidget);
      expect(find.text('Attendance 7A'), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Dashboard'), findsOneWidget);
    });

    testWidgets('all menu items cycle without stack pollution', (tester) async {
      final menus = [
        ('Teaching Schedule', 'Teaching Schedule Screen'),
        ('Class Activities', 'Class Activities Screen'),
        ('Student Attendance', 'Student Attendance Screen'),
        ('Learning Materials', 'Learning Materials Screen'),
        ('Input Grades', 'Grade Input Screen'),
        ('Grade Recap', 'Grade Recap Screen'),
        ('Report Card', 'Report Card Screen'),
        ('My Lesson Plans', 'Lesson Plans Screen'),
        ('Announcements', 'Announcements Screen'),
        ('Learning Recommendation', 'Learning Recommendation Screen'),
      ];

      for (final (title, screen) in menus) {
        await tester.pumpWidget(_buildTeacherDashboard());
        await _tapMenu(tester, title);
        expect(find.text(screen), findsOneWidget,
            reason: '$title should open $screen');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Teacher Dashboard'), findsOneWidget,
            reason: 'Back from $screen should restore Teacher Dashboard');
      }
    });
  });
}
