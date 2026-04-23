// Tests for DashboardAppBar — the pinned SliverAppBar for the dashboard.
// Must be wrapped in CustomScrollView since it is a SliverAppBar.
// Verifies school name, icon buttons, notification badge, and callback firing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';

/// Wraps DashboardAppBar (a sliver) in a minimal scrollable scaffold.
Widget buildTestable(DashboardAppBar appBar) {
  return MaterialApp(
    home: Scaffold(body: CustomScrollView(slivers: [appBar])),
  );
}

void main() {
  group('DashboardAppBar', () {
    // ── 1. Displays the school name ────────────────────────────────────────
    testWidgets('shows schoolName when provided', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'SMA Negeri 1',
            primaryColor: Colors.blue,
            onLanguageTap: () {},
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      expect(find.text('SMA Negeri 1'), findsOneWidget);
    });

    // ── 2. Shows language icon button ─────────────────────────────────────
    testWidgets('renders the language icon button', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'Test School',
            primaryColor: Colors.indigo,
            onLanguageTap: () {},
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    // ── 3. Shows notification bell icon ───────────────────────────────────
    testWidgets('renders the notification bell icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'Test School',
            primaryColor: Colors.teal,
            onLanguageTap: () {},
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    // ── 4. Notification badge shown when unreadAnnouncements > 0 ──────────
    testWidgets('shows notification badge for unread announcements', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'Test School',
            primaryColor: Colors.orange,
            unreadAnnouncements: 4,
            onLanguageTap: () {},
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget);
    });

    // ── 5. onLanguageTap fires when tapped ────────────────────────────────
    testWidgets('fires onLanguageTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'Test School',
            primaryColor: Colors.purple,
            onLanguageTap: () => tapped = true,
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.language));
      expect(tapped, isTrue);
    });

    // ── 6. Shows school icon in the logo container ────────────────────────
    testWidgets('shows the school icon in the logo container', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          DashboardAppBar(
            schoolName: 'KamilEdu',
            primaryColor: Colors.green,
            onLanguageTap: () {},
            onNotificationTap: () {},
            onAccountTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.school), findsOneWidget);
    });
  });
}
