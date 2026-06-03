// Tests for LessonPlanFieldCard — individual RPP content field with AI regen.
//
// Key scenarios:
// - Renders fieldLabel in header
// - Renders stripHtml(value) as SelectableText body
// - regenInfo=null: no quota badge rendered
// - isLoadingLimits=true: no quota badge rendered (even if regenInfo present)
// - regenInfo present + !isLoadingLimits: shows 'used/max' badge
// - isRegeneratingThis=false: star icon visible, onRegenTap fires on tap
// - isRegeneratingThis=true: spinner shown, star hidden, onRegenTap NOT fired
// - remaining=0: star icon still shown but in gray state
//
// Like testing a Vue <FieldCard> — display + one interaction delegated via
// callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_field_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _identity(String s) => s;

Widget _build({
  String fieldKey = 'core_competence',
  String fieldLabel = 'Kompetensi Inti',
  String value = 'Isi kompetensi inti',
  Map<String, dynamic>? regenInfo,
  bool isLoadingLimits = false,
  bool isRegeneratingThis = false,
  Color primaryColor = Colors.blue,
  VoidCallback? onRegenTap,
  String Function(String)? stripHtml,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: LessonPlanFieldCard(
        fieldKey: fieldKey,
        fieldLabel: fieldLabel,
        value: value,
        regenInfo: regenInfo,
        isLoadingLimits: isLoadingLimits,
        isRegeneratingThis: isRegeneratingThis,
        primaryColor: primaryColor,
        onRegenTap: onRegenTap ?? () {},
        stripHtml: stripHtml ?? _identity,
      ),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LessonPlanFieldCard — header', () {
    testWidgets('renders fieldLabel in header', (tester) async {
      await tester.pumpWidget(_build(fieldLabel: 'Kompetensi Dasar'));
      expect(find.text('Kompetensi Dasar'), findsOneWidget);
    });

    testWidgets('renders different fieldLabel', (tester) async {
      await tester.pumpWidget(_build(fieldLabel: 'Tujuan Pembelajaran'));
      expect(find.text('Tujuan Pembelajaran'), findsOneWidget);
    });
  });

  group('LessonPlanFieldCard — body content', () {
    // The body now renders the raw [value] through an HtmlWidget (which
    // handles HTML formatting itself); it is no longer a plain/SelectableText
    // and no longer pre-applies the [stripHtml] callback. Assert against the
    // HtmlWidget's html input instead of a Text finder.
    testWidgets('renders value through an HtmlWidget body', (tester) async {
      await tester.pumpWidget(_build(value: 'Peserta didik mampu berhitung'));
      final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
      expect(html.html, 'Peserta didik mampu berhitung');
    });

    testWidgets('passes raw HTML value to the HtmlWidget body', (tester) async {
      await tester.pumpWidget(_build(value: '<p>Rich <b>text</b></p>'));
      final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
      expect(html.html, '<p>Rich <b>text</b></p>');
    });
  });

  group('LessonPlanFieldCard — regen quota badge', () {
    testWidgets('no badge when regenInfo=null', (tester) async {
      await tester.pumpWidget(_build(regenInfo: null));
      // No "x/y" badge rendered
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('no badge when isLoadingLimits=true', (tester) async {
      await tester.pumpWidget(
        _build(
          regenInfo: {'remaining': 2, 'max': 3, 'used': 1},
          isLoadingLimits: true,
        ),
      );
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('shows "used/max" badge when regenInfo present + not loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          regenInfo: {'remaining': 1, 'max': 3, 'used': 2},
          isLoadingLimits: false,
        ),
      );
      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('shows "0/2" badge when both used=0 and max=2', (tester) async {
      await tester.pumpWidget(
        _build(
          regenInfo: {'remaining': 2, 'max': 2, 'used': 0},
          isLoadingLimits: false,
        ),
      );
      expect(find.text('0/2'), findsOneWidget);
    });
  });

  group('LessonPlanFieldCard — regen button states', () {
    testWidgets('shows star icon when not regenerating', (tester) async {
      await tester.pumpWidget(_build(isRegeneratingThis: false));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner when isRegeneratingThis=true', (tester) async {
      await tester.pumpWidget(_build(isRegeneratingThis: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('fires onRegenTap when star tapped and not regenerating', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _build(isRegeneratingThis: false, onRegenTap: () => tapped = true),
      );
      await tester.tap(find.byIcon(Icons.star_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('does NOT fire onRegenTap when isRegeneratingThis=true', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _build(isRegeneratingThis: true, onRegenTap: () => tapped = true),
      );
      // spinner is shown, tapping the InkWell area has onTap=null
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      expect(tapped, isFalse);
    });
  });

  group('LessonPlanFieldCard — regenInfo null defaults', () {
    testWidgets('defaults remaining=2 when regenInfo=null (no crash)', (
      tester,
    ) async {
      // Should not throw — falls back to remaining=2
      await tester.pumpWidget(
        _build(
          regenInfo: null,
          isLoadingLimits: false,
          isRegeneratingThis: false,
        ),
      );
      expect(find.byType(LessonPlanFieldCard), findsOneWidget);
    });
  });
}
