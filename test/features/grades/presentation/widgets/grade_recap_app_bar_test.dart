// Tests for GradeRecapAppBar — the gradient wizard header widget.
//
// Key scenarios:
// - Step 0: subtitle = selectClassLabel, save button hidden
// - Step 1: subtitle = selectedClassName, save button hidden
// - Step 2: subtitle = selectedSubjectName, save button shown
// - isSaving=true on step 2: CircularProgressIndicator replaces save icon
// - isSaving=false on step 2: Save icon visible and tappable
// - onBack fires on back button tap
// - onSave fires on save button tap (step 2, not saving)
// - Title is always rendered
//
// Like testing a Vue wizard header — purely presentational, all state via props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_app_bar.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  int currentStep = 0,
  Color primaryColor = Colors.indigo,
  String title = 'Rekap Nilai',
  String selectClassLabel = 'Pilih Kelas',
  String selectedClassName = 'Kelas 7A',
  String selectedSubjectName = 'Matematika',
  String updateDataLabel = 'Perbarui Data',
  bool isSaving = false,
  VoidCallback? onBack,
  VoidCallback? onSave,
  VoidCallback? onRefresh,
  VoidCallback? onExportExcel,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GradeRecapAppBar(
        currentStep: currentStep,
        primaryColor: primaryColor,
        title: title,
        selectClassLabel: selectClassLabel,
        selectedClassName: selectedClassName,
        selectedSubjectName: selectedSubjectName,
        updateDataLabel: updateDataLabel,
        saveKey: GlobalKey(),
        exportKey: GlobalKey(),
        isSaving: isSaving,
        onBack: onBack ?? () {},
        onSave: onSave ?? () {},
        onRefresh: onRefresh ?? () {},
        onExportExcel: onExportExcel ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GradeRecapAppBar — title', () {
    testWidgets('renders title on step 0', (tester) async {
      await tester.pumpWidget(_build(currentStep: 0, title: 'Rekap Nilai'));
      expect(find.text('Rekap Nilai'), findsOneWidget);
    });

    testWidgets('renders title on step 2', (tester) async {
      await tester.pumpWidget(_build(currentStep: 2, title: 'Grade Recap'));
      expect(find.text('Grade Recap'), findsOneWidget);
    });
  });

  group('GradeRecapAppBar — subtitle (step-aware)', () {
    testWidgets('step 0 shows selectClassLabel', (tester) async {
      await tester.pumpWidget(
        _build(currentStep: 0, selectClassLabel: 'Pilih Kelas'),
      );
      expect(find.text('Pilih Kelas'), findsOneWidget);
    });

    testWidgets('step 1 shows selectedClassName', (tester) async {
      await tester.pumpWidget(
        _build(currentStep: 1, selectedClassName: 'Kelas 8B'),
      );
      expect(find.text('Kelas 8B'), findsOneWidget);
    });

    testWidgets('step 2 shows selectedSubjectName', (tester) async {
      await tester.pumpWidget(
        _build(currentStep: 2, selectedSubjectName: 'Fisika'),
      );
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('step 1 does NOT show selectClassLabel', (tester) async {
      await tester.pumpWidget(
        _build(
          currentStep: 1,
          selectClassLabel: 'Pilih Kelas',
          selectedClassName: 'Kelas 9A',
        ),
      );
      expect(find.text('Pilih Kelas'), findsNothing);
    });
  });

  group('GradeRecapAppBar — save button visibility', () {
    testWidgets('save button is NOT shown on step 0', (tester) async {
      await tester.pumpWidget(_build(currentStep: 0));
      expect(find.byIcon(Icons.save), findsNothing);
    });

    testWidgets('save button is NOT shown on step 1', (tester) async {
      await tester.pumpWidget(_build(currentStep: 1));
      expect(find.byIcon(Icons.save), findsNothing);
    });

    testWidgets('save button IS shown on step 2 when not saving', (
      tester,
    ) async {
      await tester.pumpWidget(_build(currentStep: 2, isSaving: false));
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('save button shows spinner on step 2 when isSaving=true', (
      tester,
    ) async {
      await tester.pumpWidget(_build(currentStep: 2, isSaving: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
    });
  });

  group('GradeRecapAppBar — callbacks', () {
    testWidgets('onBack fires when back button tapped', (tester) async {
      bool backCalled = false;
      await tester.pumpWidget(_build(onBack: () => backCalled = true));
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backCalled, isTrue);
    });

    testWidgets('onSave fires on step 2 when not saving', (tester) async {
      bool saveCalled = false;
      await tester.pumpWidget(
        _build(
          currentStep: 2,
          isSaving: false,
          onSave: () => saveCalled = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.save));
      expect(saveCalled, isTrue);
    });

    testWidgets('onSave NOT fired when isSaving=true (tap disabled)', (
      tester,
    ) async {
      bool saveCalled = false;
      await tester.pumpWidget(
        _build(currentStep: 2, isSaving: true, onSave: () => saveCalled = true),
      );
      // Tap the container that holds the spinner — onTap is null when saving
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(saveCalled, isFalse);
    });
  });

  group('GradeRecapAppBar — popup menu', () {
    testWidgets('popup menu icon is always visible', (tester) async {
      await tester.pumpWidget(_build(currentStep: 0));
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('refresh option appears in popup menu', (tester) async {
      await tester.pumpWidget(
        _build(currentStep: 0, updateDataLabel: 'Perbarui Data'),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Perbarui Data'), findsOneWidget);
    });

    testWidgets('export Excel option shown in popup on step 2', (tester) async {
      await tester.pumpWidget(_build(currentStep: 2));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Export Excel'), findsOneWidget);
    });

    testWidgets('export Excel option NOT shown in popup on step 0', (
      tester,
    ) async {
      await tester.pumpWidget(_build(currentStep: 0));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Export Excel'), findsNothing);
    });

    testWidgets('onRefresh fires when refresh popup item selected', (
      tester,
    ) async {
      bool refreshCalled = false;
      await tester.pumpWidget(
        _build(
          currentStep: 0,
          updateDataLabel: 'Perbarui Data',
          onRefresh: () => refreshCalled = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perbarui Data'));
      await tester.pumpAndSettle();
      expect(refreshCalled, isTrue);
    });
  });
}
