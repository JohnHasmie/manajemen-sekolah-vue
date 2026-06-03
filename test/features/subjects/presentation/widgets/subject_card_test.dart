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
        _wrap(
          SubjectCard(
            subject: _subject(),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Matematika'), findsOneWidget);
    });

    testWidgets('renders subject code', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: _subject(code: 'MTK'),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      // SS2 redesign: the code now lives in the combined top-meta line
      // "<code> · <N> kelas" (id default).
      expect(find.text('MTK · 3 kelas'), findsOneWidget);
    });

    testWidgets('fires onTap when card body is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: _subject(),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () => tapped = true,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('fires onEdit on long-press', (tester) async {
      // SS2 redesign: edit is triggered via long-press, not an icon button.
      bool edited = false;
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: _subject(),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () => edited = true,
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Matematika'));
      expect(edited, isTrue);
    });

    testWidgets('shows Detail CTA and no inline edit/delete icons', (
      tester,
    ) async {
      // SS2 redesign: inline edit/delete icon buttons were removed in favor
      // of a "Detail →" trailing CTA. Deletion happens off-card (detail
      // sheet / bulk-select), so there is no per-row delete icon.
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: _subject(),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Detail →'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('avatar shows initials of subject name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: _subject(name: 'Bahasa Indonesia'),
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      // InitialsAvatar shows two-letter initials of "Bahasa Indonesia" → 'BI'.
      expect(find.text('BI'), findsOneWidget);
    });

    testWidgets('uses kode fallback when code key is absent', (tester) async {
      final subject = {
        'name': 'IPA',
        'kode': 'IPA01',
        'is_active': true,
        'jumlah_kelas': 1,
      };
      await tester.pumpWidget(
        _wrap(
          SubjectCard(
            subject: subject,
            index: 0,
            primaryColor: Colors.blue,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pump();
      // Code falls back to the `kode` key; rendered in the top-meta line.
      expect(find.text('IPA01 · 1 kelas'), findsOneWidget);
    });
  });
}
