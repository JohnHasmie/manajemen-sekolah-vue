// Tests for StudentSectionHeader — section title with left-border accent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_section_header.dart';

Widget _build({
  IconData icon = Icons.person_outline,
  String title = 'Informasi Pribadi',
  Color primaryColor = Colors.blue,
}) => MaterialApp(
  home: Scaffold(
    body: StudentSectionHeader(
      icon: icon,
      title: title,
      primaryColor: primaryColor,
    ),
  ),
);

void main() {
  group('StudentSectionHeader', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(StudentSectionHeader), findsOneWidget);
    });

    testWidgets('displays the title', (tester) async {
      await tester.pumpWidget(_build(title: 'Data Orang Tua'));
      expect(find.text('Data Orang Tua'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.home_outlined));
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.home_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('icon has size 16', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.person_outline));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.person_outline,
        ),
      );
      expect(icon.size, 16);
    });

    testWidgets('title has font size 13', (tester) async {
      await tester.pumpWidget(_build(title: 'Akademik'));
      final text = tester.widget<Text>(find.text('Akademik'));
      expect(text.style?.fontSize, 13);
    });

    testWidgets('handles empty title without crashing', (tester) async {
      await tester.pumpWidget(_build(title: ''));
      expect(find.byType(StudentSectionHeader), findsOneWidget);
    });

    testWidgets('renders with different primaryColor values', (tester) async {
      for (final c in [Colors.teal, Colors.indigo, Colors.orange]) {
        await tester.pumpWidget(_build(primaryColor: c));
        expect(find.byType(StudentSectionHeader), findsOneWidget);
      }
    });

    testWidgets('displays English title correctly', (tester) async {
      await tester.pumpWidget(_build(title: 'Personal Information'));
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets('can render multiple headers in a column', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudentSectionHeader(
                  icon: Icons.person_outline,
                  title: 'Pribadi',
                  primaryColor: Colors.blue,
                ),
                StudentSectionHeader(
                  icon: Icons.school_outlined,
                  title: 'Akademik',
                  primaryColor: Colors.green,
                ),
                StudentSectionHeader(
                  icon: Icons.home_outlined,
                  title: 'Alamat',
                  primaryColor: Colors.orange,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(StudentSectionHeader), findsNWidgets(3));
    });
  });
}
