// Tests for AttendanceTeacherHeader.
// Requires a TabController (needs a TickerProvider) and a LanguageProvider.
// We use SingleTickerProviderStateMixin via a StatefulWidget wrapper.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_teacher_header.dart';

// A thin wrapper that owns the TabController lifecycle so the test widget
// can provide a valid vsync — like mounting a parent component in a Vue test.
class _HeaderWrapper extends StatefulWidget {
  final int currentTabIndex;
  final bool hasClassSelected;
  final LanguageProvider languageProvider;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _HeaderWrapper({
    required this.currentTabIndex,
    required this.hasClassSelected,
    required this.languageProvider,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<_HeaderWrapper> createState() => _HeaderWrapperState();
}

class _HeaderWrapperState extends State<_HeaderWrapper>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Move to the requested tab so the title reflects currentTabIndex.
    _tabController.index = widget.currentTabIndex;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AttendanceTeacherHeader(
      tabController: _tabController,
      tabSwitcherKey: GlobalKey(),
      primaryColor: Colors.blue,
      gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
      currentTabIndex: widget.currentTabIndex,
      hasClassSelected: widget.hasClassSelected,
      languageProvider: widget.languageProvider,
      onBack: widget.onBack,
      onRefresh: widget.onRefresh,
    );
  }
}

void main() {
  late LanguageProvider langProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    langProvider = LanguageProvider();
  });

  Widget buildWidget({
    int currentTabIndex = 0,
    bool hasClassSelected = false,
    VoidCallback? onBack,
    VoidCallback? onRefresh,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: _HeaderWrapper(
          currentTabIndex: currentTabIndex,
          hasClassSelected: hasClassSelected,
          languageProvider: langProvider,
          onBack: onBack ?? () {},
          onRefresh: onRefresh ?? () {},
        ),
      ),
    );
  }

  group('AttendanceTeacherHeader', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceTeacherHeader), findsOneWidget);
    });

    testWidgets('shows "Hasil Absensi" title when tab index is 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(currentTabIndex: 0));
      // Default language is Indonesian — check for Indonesian title text.
      expect(find.text('Hasil Absensi'), findsWidgets);
    });

    testWidgets('shows "Tambah Absensi" title when tab index is 1', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(currentTabIndex: 1));
      expect(find.text('Tambah Absensi'), findsWidgets);
    });

    testWidgets('back button fires onBack callback', (
      WidgetTester tester,
    ) async {
      bool backCalled = false;
      await tester.pumpWidget(buildWidget(onBack: () => backCalled = true));

      final backIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.arrow_back,
      );
      expect(backIcon, findsOneWidget);
      await tester.tap(backIcon);
      await tester.pump();

      expect(backCalled, isTrue);
    });

    testWidgets('overflow menu icon is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      final moreIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.more_vert,
      );
      expect(moreIcon, findsOneWidget);
    });

    testWidgets('tab switcher contains both tab labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      // Both tab items should be rendered inside the TabSwitcher.
      expect(find.text('Hasil Absensi'), findsWidgets);
      expect(find.text('Tambah Absensi'), findsWidgets);
    });
  });
}
