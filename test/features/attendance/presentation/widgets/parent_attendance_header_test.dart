// Tests for ParentAttendanceHeader.
// Uses LanguageProvider + PreferencesService (for .tr extension).
// AppNavigator.pop is called when the back button is tapped — MaterialApp
// provides a Navigator so the pop completes without error.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_header.dart';

void main() {
  late LanguageProvider langProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    langProvider = LanguageProvider();
  });

  Widget buildWidget({
    String? studentName,
    bool hasActiveFilter = false,
    List<Map<String, dynamic>> filterChips = const [],
    VoidCallback? onSearchChanged,
    VoidCallback? onFilterTap,
    VoidCallback? onClearAllFilters,
    VoidCallback? onRefresh,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ParentAttendanceHeader(
            gradient: const LinearGradient(colors: [Colors.teal, Colors.green]),
            primaryColor: Colors.teal,
            studentName: studentName,
            hasActiveFilter: hasActiveFilter,
            searchController: TextEditingController(),
            filterChips: filterChips,
            languageProvider: langProvider,
            onSearchChanged: onSearchChanged ?? () {},
            onFilterTap: onFilterTap ?? () {},
            onClearAllFilters: onClearAllFilters ?? () {},
            onRefresh: onRefresh ?? () {},
          ),
        ),
      ),
    );
  }

  group('ParentAttendanceHeader', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(ParentAttendanceHeader), findsOneWidget);
    });

    testWidgets('shows student name when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(studentName: 'Siti Rahayu'));
      expect(find.text('Siti Rahayu'), findsOneWidget);
    });

    testWidgets('student name is absent when null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(studentName: null));
      expect(find.text('Siti Rahayu'), findsNothing);
    });

    testWidgets('filter button fires onFilterTap', (WidgetTester tester) async {
      bool filterTapped = false;
      await tester.pumpWidget(
        buildWidget(onFilterTap: () => filterTapped = true),
      );
      final filterIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.tune_rounded,
      );
      expect(filterIcon, findsOneWidget);
      await tester.tap(filterIcon);
      await tester.pump();
      expect(filterTapped, isTrue);
    });

    testWidgets('search field fires onSearchChanged on text input', (
      WidgetTester tester,
    ) async {
      bool changed = false;
      await tester.pumpWidget(
        buildWidget(onSearchChanged: () => changed = true),
      );
      await tester.enterText(find.byType(TextField), 'Mat');
      expect(changed, isTrue);
    });

    testWidgets('filter chip label is shown when hasActiveFilter is true', (
      WidgetTester tester,
    ) async {
      final chips = [
        {'label': 'Hadir', 'onRemove': () {}},
      ];
      await tester.pumpWidget(
        buildWidget(hasActiveFilter: true, filterChips: chips),
      );
      expect(find.text('Hadir'), findsOneWidget);
    });
  });
}
