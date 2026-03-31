// Widget tests for SubjectCard.
// SubjectCard is a ConsumerWidget that reads languageRiverpod, so we wrap the
// tree with ProviderScope and override the provider with a pre-built
// LanguageProvider instance — the same pattern used for other Riverpod widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_card.dart';

Widget _wrap(Widget child) {
  final lang = LanguageProvider();
  return ProviderScope(
    overrides: [languageRiverpod.overrideWith((_) => lang)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Map<String, dynamic> _subject({
  String name = 'Matematika',
  String code = 'MTK',
  bool isActive = true,
  int classCount = 3,
  String? klassNames,
}) => {
      'name': name,
      'code': code,
      'is_active': isActive,
      'jumlah_kelas': classCount,
      if (klassNames != null) 'kelas_names': klassNames,
    };

void main() {
  group('SubjectCard', () {
    testWidgets('renders subject name', (tester) async {
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        )),
      );
      await tester.pump();
      expect(find.text('Matematika'), findsOneWidget);
    });

    testWidgets('renders subject code', (tester) async {
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(code: 'MTK'),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        )),
      );
      await tester.pump();
      expect(find.text('MTK'), findsOneWidget);
    });

    testWidgets('fires onTap when card body is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () => tapped = true,
          onEdit: () {},
          onDelete: () {},
        )),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('fires onEdit when pencil button is tapped', (tester) async {
      bool edited = false;
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () => edited = true,
          onDelete: () {},
        )),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      expect(edited, isTrue);
    });

    testWidgets('fires onDelete when trash button is tapped', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () {},
          onDelete: () => deleted = true,
        )),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });

    testWidgets('avatar shows first letter of subject name', (tester) async {
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: _subject(name: 'Bahasa Indonesia'),
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        )),
      );
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('uses kode fallback when code key is absent', (tester) async {
      final subject = {
        'name': 'IPA',
        'kode': 'IPA01',
        'is_active': true,
        'jumlah_kelas': 1,
      };
      await tester.pumpWidget(
        _wrap(SubjectCard(
          subject: subject,
          index: 0,
          primaryColor: Colors.blue,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        )),
      );
      await tester.pump();
      expect(find.text('IPA01'), findsOneWidget);
    });
  });
}
