// Tests for the EnhancedSearchBar widget.
//
// Covers rendering, hint text, the clear button, onChanged callback, and
// the optional filter dropdown. No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/enhanced_search_bar.dart';

void main() {
  group('EnhancedSearchBar', () {
    // Helper that wires up the widget with the given options.
    Widget buildWidget({
      TextEditingController? controller,
      String hintText = 'Cari...',
      ValueChanged<String>? onChanged,
      List<String>? filterOptions,
      String? selectedFilter,
      ValueChanged<String>? onFilterChanged,
      bool showFilter = false,
    }) {
      final ctrl = controller ?? TextEditingController();
      return MaterialApp(
        home: Scaffold(
          body: EnhancedSearchBar(
            controller: ctrl,
            hintText: hintText,
            onChanged: onChanged,
            filterOptions: filterOptions,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            showFilter: showFilter,
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(EnhancedSearchBar), findsOneWidget);
    });

    testWidgets('shows hint text inside the text field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(hintText: 'Search students...'));
      // The hint is displayed as decoration hint text inside TextField.
      expect(find.text('Search students...'), findsOneWidget);
    });

    testWidgets('search icon is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.search_rounded,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('fires onChanged when text is entered', (
      WidgetTester tester,
    ) async {
      String? captured;
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        buildWidget(controller: ctrl, onChanged: (v) => captured = v),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      expect(captured, 'hello');
    });

    testWidgets('clear button appears when controller has text', (
      WidgetTester tester,
    ) async {
      final ctrl = TextEditingController(text: 'abc');
      await tester.pumpWidget(buildWidget(controller: ctrl));
      // Rebuild so the widget picks up the pre-filled text.
      await tester.pump();
      final clearIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.clear,
      );
      expect(clearIcon, findsOneWidget);
    });

    testWidgets('clear button is absent when controller is empty', (
      WidgetTester tester,
    ) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(buildWidget(controller: ctrl));
      await tester.pump();
      final clearIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.clear,
      );
      expect(clearIcon, findsNothing);
    });

    testWidgets('filter dropdown is shown when showFilter is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          showFilter: true,
          filterOptions: ['All', 'Active', 'Inactive'],
          selectedFilter: 'All',
        ),
      );
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('filter dropdown is hidden when showFilter is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          showFilter: false,
          filterOptions: ['All', 'Active'],
          selectedFilter: 'All',
        ),
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
    });
  });
}
