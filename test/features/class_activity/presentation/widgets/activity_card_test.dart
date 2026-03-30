// Tests for ActivityCard — a list row card for one class activity entry.
// Uses LanguageProvider (ChangeNotifier, not WidgetRef) so setUp initialises
// PreferencesService with mock SharedPreferences before each test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  // Returns a minimal activity map for a "material" entry.
  Map<String, dynamic> materialActivity() => {
        'title': 'Matematika Bab 3',
        'subject_name': 'Matematika',
        'class_name': '10A',
        'jenis': 'materi',
        'day': 'Senin',
        'date': '2025-06-09',
        'deskripsi': 'Belajar integral dasar',
        'target_role': 'semua',
      };

  // Returns a minimal activity map for a "tugas" (assignment) entry.
  Map<String, dynamic> assignmentActivity() => {
        'title': 'PR Fisika',
        'subject_name': 'Fisika',
        'class_name': '11B',
        'jenis': 'tugas',
        'day': 'Selasa',
        'date': '2025-06-10',
        'batas_waktu': '2025-06-17',
        'target_role': 'semua',
      };

  Widget buildSubject({
    required Map<String, dynamic> activity,
    bool canEdit = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final provider = LanguageProvider();
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityCard(
            activity: activity,
            primaryColor: Colors.blue,
            languageProvider: provider,
            canEdit: canEdit,
            onTap: onTap ?? () {},
            onEdit: onEdit ?? () {},
            onDelete: onDelete ?? () {},
          ),
        ),
      ),
    );
  }

  group('ActivityCard', () {
    testWidgets('shows activity title', (tester) async {
      await tester.pumpWidget(buildSubject(activity: materialActivity()));

      expect(find.text('Matematika Bab 3'), findsOneWidget);
    });

    testWidgets('shows subject and class name row', (tester) async {
      await tester.pumpWidget(buildSubject(activity: materialActivity()));

      // The combined "Matematika • 10A" text should be visible.
      expect(find.textContaining('Matematika'), findsWidgets);
      expect(find.textContaining('10A'), findsWidgets);
    });

    testWidgets('shows edit and delete buttons when canEdit is true',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(activity: materialActivity(), canEdit: true),
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows chevron (read-only) when canEdit is false',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(activity: materialActivity(), canEdit: false),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('fires onTap when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(
          activity: materialActivity(),
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('assignment activity renders deadline tag when batas_waktu set',
        (tester) async {
      await tester.pumpWidget(buildSubject(activity: assignmentActivity()));

      // The deadline date should appear as a formatted tag (17/06/2025).
      expect(find.textContaining('17/06/2025'), findsOneWidget);
    });
  });
}
