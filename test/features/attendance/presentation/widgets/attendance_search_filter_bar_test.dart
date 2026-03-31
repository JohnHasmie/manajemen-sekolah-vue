// Tests for AttendanceSearchFilterBar.
// Uses LanguageProvider + PreferencesService for the hint text translation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_search_filter_bar.dart';

void main() {
  late LanguageProvider langProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    langProvider = LanguageProvider();
  });

  Widget buildWidget({
    bool hasActiveFilter = false,
    bool showFilterButton = true,
    VoidCallback? onSearchChanged,
    VoidCallback? onFilterTap,
    TextEditingController? controller,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AttendanceSearchFilterBar(
          searchController: controller ?? TextEditingController(),
          searchFilterKey: GlobalKey(),
          hasActiveFilter: hasActiveFilter,
          primaryColor: Colors.blue,
          showFilterButton: showFilterButton,
          languageProvider: langProvider,
          onSearchChanged: onSearchChanged ?? () {},
          onFilterTap: onFilterTap ?? () {},
        ),
      ),
    );
  }

  group('AttendanceSearchFilterBar', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceSearchFilterBar), findsOneWidget);
    });

    testWidgets('shows hint text in search field', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      // Default language is Indonesian → 'Cari absensi...'
      expect(find.text('Cari absensi...'), findsOneWidget);
    });

    testWidgets('filter button is visible when showFilterButton is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(showFilterButton: true));
      final tuneIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.tune,
      );
      expect(tuneIcon, findsOneWidget);
    });

    testWidgets('filter button is hidden when showFilterButton is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(showFilterButton: false));
      final tuneIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.tune,
      );
      expect(tuneIcon, findsNothing);
    });

    testWidgets('onFilterTap fires when filter button is tapped',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildWidget(
          showFilterButton: true,
          onFilterTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('onSearchChanged fires when text is typed',
        (WidgetTester tester) async {
      bool changed = false;
      await tester.pumpWidget(
        buildWidget(onSearchChanged: () => changed = true),
      );
      await tester.enterText(find.byType(TextField), 'Bio');
      expect(changed, isTrue);
    });
  });
}
