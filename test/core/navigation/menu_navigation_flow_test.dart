/// Navigation flow tests for dashboard menu cards and quick-action buttons.
///
/// Tests the full round-trip: tap card → navigate to screen → back → return.
/// Also tests that multiple menu items in a grid navigate to DIFFERENT screens
/// and that back always restores the correct previous screen.
///
/// Like integration-testing Vue Router links in a navigation menu:
/// click a link → right page appears → browser back → menu restored.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a row of [MenuItemCard]s, each navigating to a unique screen.
Widget _buildMenuGrid(
  List<({String title, dynamic icon, String destination})> items,
) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Builder(
        builder: (ctx) {
          return Column(
            children: items.map((item) {
              return MenuItemCard(
                title: item.title,
                icon: item.icon,
                onTap: () => AppNavigator.push(
                  ctx,
                  Scaffold(
                    appBar: AppBar(title: Text(item.destination)),
                    body: Text('Content: ${item.destination}'),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ),
  );
}

/// Builds a row of [QuickActionButton]s, each navigating to a unique screen.
Widget _buildQuickActions(
  List<({String label, IconData icon, String destination})> items,
) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Builder(
        builder: (ctx) {
          return Row(
            children: items.map((item) {
              return QuickActionButton(
                label: item.label,
                icon: item.icon,
                color: Colors.blue,
                onTap: () => AppNavigator.push(
                  ctx,
                  Scaffold(
                    appBar: AppBar(title: Text(item.destination)),
                    body: Text('Content: ${item.destination}'),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — MenuItemCard Navigation Flows
// ---------------------------------------------------------------------------

void main() {
  group('MenuItemCard — navigation flow: tap → screen → back', () {
    testWidgets(
      'tapping "Data Siswa" opens student screen and back returns to menu',
      (tester) async {
        await tester.pumpWidget(
          _buildMenuGrid([
            (
              title: 'Data Siswa',
              icon: Icons.person_outline,
              destination: 'Student Screen',
            ),
          ]),
        );

        // Confirm we're on the menu
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Data Siswa'), findsOneWidget);

        // Navigate forward
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.text('Student Screen'), findsOneWidget);
        expect(find.text('Content: Student Screen'), findsOneWidget);

        // Navigate back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Data Siswa'), findsOneWidget);
        expect(find.text('Student Screen'), findsNothing);
      },
    );

    testWidgets('each menu item navigates to its own unique screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildMenuGrid([
          (
            title: 'Jadwal',
            icon: Icons.calendar_today,
            destination: 'Schedule Screen',
          ),
          (
            title: 'Keuangan',
            icon: Icons.payments,
            destination: 'Finance Screen',
          ),
          (
            title: 'Pengumuman',
            icon: Icons.campaign,
            destination: 'Announcement Screen',
          ),
        ]),
      );

      final inkWells = find.byType(InkWell);

      // --- Jadwal ---
      await tester.tap(inkWells.at(0));
      await tester.pumpAndSettle();
      expect(find.text('Schedule Screen'), findsOneWidget);
      expect(find.text('Finance Screen'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // --- Keuangan ---
      await tester.tap(inkWells.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Finance Screen'), findsOneWidget);
      expect(find.text('Schedule Screen'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // --- Pengumuman ---
      await tester.tap(inkWells.at(2));
      await tester.pumpAndSettle();
      expect(find.text('Announcement Screen'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // All back at menu
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('back button always restores correct menu title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildMenuGrid([
          (
            title: 'RPP',
            icon: Icons.article,
            destination: 'Lesson Plan Screen',
          ),
        ]),
      );

      // Go forward twice (simulate re-entry)
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.text('Lesson Plan Screen'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('RPP'), findsOneWidget);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Deep navigation: 3 levels
  // -------------------------------------------------------------------------
  group('MenuItemCard — deep navigation (3 levels)', () {
    testWidgets('level1 → level2 → level3 → back → back → menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx1) {
              return Scaffold(
                appBar: AppBar(title: const Text('Menu')),
                body: MenuItemCard(
                  title: 'Nilai',
                  icon: Icons.grade,
                  onTap: () => AppNavigator.push(
                    ctx1,
                    Builder(
                      builder: (ctx2) {
                        return Scaffold(
                          appBar: AppBar(title: const Text('Class List')),
                          body: MenuItemCard(
                            title: 'Kelas 7A',
                            icon: Icons.class_outlined,
                            onTap: () => AppNavigator.push(
                              ctx2,
                              Builder(
                                builder: (ctx3) {
                                  return Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Grade Book'),
                                    ),
                                    body: const Text('Grade table here'),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Level 1 → 2
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('Class List'), findsOneWidget);

      // Level 2 → 3
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('Grade Book'), findsOneWidget);
      expect(find.text('Grade table here'), findsOneWidget);

      // Back to level 2
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Class List'), findsOneWidget);
      expect(find.text('Grade Book'), findsNothing);

      // Back to menu
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Class List'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // QuickActionButton navigation flows
  // -------------------------------------------------------------------------
  group('QuickActionButton — navigation flow: tap → screen → back', () {
    testWidgets('tapping quick action opens screen and back returns', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildQuickActions([
          (
            label: 'Absensi',
            icon: Icons.fact_check,
            destination: 'Attendance Screen',
          ),
        ]),
      );

      expect(find.text('Absensi'), findsOneWidget);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('Attendance Screen'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Absensi'), findsOneWidget);
    });

    testWidgets('three quick actions navigate to three distinct screens', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildQuickActions([
          (label: 'Absensi', icon: Icons.fact_check, destination: 'Attendance'),
          (label: 'Nilai', icon: Icons.grade, destination: 'Grades'),
          (label: 'Materi', icon: Icons.book, destination: 'Materials'),
        ]),
      );

      final inkWells = find.byType(InkWell);

      for (final (index, dest) in [
        (0, 'Attendance'),
        (1, 'Grades'),
        (2, 'Materials'),
      ]) {
        await tester.tap(inkWells.at(index));
        await tester.pumpAndSettle();
        expect(find.text(dest), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
      }
    });

    testWidgets('quick action with badge navigates correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Dashboard')),
            body: Builder(
              builder: (ctx) {
                return QuickActionButton(
                  label: 'Notifikasi',
                  icon: Icons.notifications,
                  color: Colors.orange,
                  badgeCount: 3,
                  onTap: () => AppNavigator.push(
                    ctx,
                    Scaffold(
                      appBar: AppBar(title: const Text('Notifications')),
                      body: const Text('3 notifikasi baru'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Badge visible
      expect(find.text('3'), findsOneWidget);

      // Navigate forward
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('3 notifikasi baru'), findsOneWidget);

      // Back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge still there
    });
  });

  // -------------------------------------------------------------------------
  // Mixed menu + back-stack integrity
  // -------------------------------------------------------------------------
  group('Mixed navigation — back-stack integrity', () {
    testWidgets(
      'navigating between different menus preserves correct back stack',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx0) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Main Menu')),
                  body: Column(
                    children: [
                      MenuItemCard(
                        title: 'Section A',
                        icon: Icons.folder,
                        onTap: () => AppNavigator.push(
                          ctx0,
                          Builder(
                            builder: (ctxA) {
                              return Scaffold(
                                appBar: AppBar(title: const Text('Section A')),
                                body: MenuItemCard(
                                  title: 'Item A1',
                                  icon: Icons.article,
                                  onTap: () => AppNavigator.push(
                                    ctxA,
                                    Scaffold(
                                      appBar: AppBar(
                                        title: const Text('Page A1'),
                                      ),
                                      body: const Text('A1 content'),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      MenuItemCard(
                        title: 'Section B',
                        icon: Icons.folder_open,
                        onTap: () => AppNavigator.push(
                          ctx0,
                          Scaffold(
                            appBar: AppBar(title: const Text('Section B')),
                            body: const Text('Section B content'),
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

        final inkWells = find.byType(InkWell);

        // Go A → A1
        await tester.tap(inkWells.at(0));
        await tester.pumpAndSettle();
        expect(find.text('Section A'), findsOneWidget);

        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.text('Page A1'), findsOneWidget);

        // Pop A1 → A
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Section A'), findsOneWidget);

        // Pop A → Main Menu
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Main Menu'), findsOneWidget);

        // Now go to B directly
        await tester.tap(inkWells.at(1));
        await tester.pumpAndSettle();
        expect(find.text('Section B content'), findsOneWidget);
        expect(find.text('Main Menu'), findsNothing);

        // Pop B → Main Menu
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Main Menu'), findsOneWidget);
      },
    );

    testWidgets('pushReplacement on logout — clears back stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                appBar: AppBar(title: const Text('Home')),
                body: Column(
                  children: [
                    ElevatedButton(
                      key: const Key('go_deep'),
                      onPressed: () => AppNavigator.push(
                        ctx,
                        Scaffold(
                          appBar: AppBar(title: const Text('Deep Screen')),
                          body: const Text('deep content'),
                        ),
                      ),
                      child: const Text('Go Deep'),
                    ),
                    ElevatedButton(
                      key: const Key('logout'),
                      onPressed: () => AppNavigator.pushAndClearStack(
                        ctx,
                        const Scaffold(body: Text('Login Screen')),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Push a deep screen first
      await tester.tap(find.byKey(const Key('go_deep')));
      await tester.pumpAndSettle();
      expect(find.text('Deep Screen'), findsOneWidget);

      // Go back and logout
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      // After clear-stack push, no back button
      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
