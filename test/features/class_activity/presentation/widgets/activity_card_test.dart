// Tests for ActivityCard — refined card with type indicator + overflow menu.
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

    testWidgets('shows date in meta row', (tester) async {
      await tester.pumpWidget(buildSubject(activity: materialActivity()));
      expect(find.textContaining('09/06/2025'), findsOneWidget);
    });

    testWidgets('shows type label for material', (tester) async {
      await tester.pumpWidget(buildSubject(activity: materialActivity()));
      expect(find.text('Materi'), findsOneWidget);
    });

    testWidgets('shows overflow menu when canEdit is true', (tester) async {
      await tester.pumpWidget(
        buildSubject(activity: materialActivity(), canEdit: true),
      );
      // Overflow menu icon is more_vert
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows chevron when canEdit is false', (tester) async {
      await tester.pumpWidget(
        buildSubject(activity: materialActivity(), canEdit: false),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('fires onTap when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(activity: materialActivity(), onTap: () => tapped = true),
      );
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('assignment shows deadline', (tester) async {
      await tester.pumpWidget(buildSubject(activity: assignmentActivity()));
      expect(find.textContaining('17/06/2025'), findsOneWidget);
    });

    testWidgets('shows description text when present', (tester) async {
      await tester.pumpWidget(buildSubject(activity: materialActivity()));
      expect(find.text('Belajar integral dasar'), findsOneWidget);
    });
  });
}
