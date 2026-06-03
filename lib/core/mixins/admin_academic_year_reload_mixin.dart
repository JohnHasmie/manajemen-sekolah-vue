// Shared "reload when the user switches academic year on the dashboard"
// mixin. Replaces the copy-pasted listener pattern that lived in 6+
// admin screens (admin_teacher_management, admin_student_management,
// admin_classroom_management, admin_grade_overview, admin_raport_hub,
// admin_schedule_management).
//
// How to use
// ----------
//   class _MyScreenState extends ConsumerState<MyScreen>
//       with AdminAcademicYearReloadMixin<MyScreen> {
//     @override
//     void onAcademicYearChanged() => _loadData();
//
//     Future<void> _loadData() async {
//       await service.fetchSomething(academicYearId: currentAcademicYearId);
//     }
//   }
//
// The mixin:
//   • Captures the riverpod-exposed `AcademicYearProvider` (a
//     ChangeNotifier) on initState and attaches the listener.
//   • Removes the listener on dispose.
//   • Exposes `currentAcademicYearId` so the screen can pass it into
//     its service calls without re-reading the provider every time.
//   • Exposes `isAcademicYearReadOnly` so the screen can disable
//     write actions when the user is browsing a past AY.
//   • Calls the abstract `onAcademicYearChanged()` method whenever
//     the listener fires.
//
// Notes
// -----
// • This mixin is intentionally scoped to admin screens. Teacher and
//   parent dashboards already react to the same provider via their
//   own bespoke wiring (see ParentDashboardBody / TeacherDashboardBody).
//   Migrating those is out of scope for this mixin.
// • The mixin is generic over the screen's StatefulWidget so the
//   subtype constraint on `ConsumerState<T>` matches each consumer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';

mixin AdminAcademicYearReloadMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Cached provider reference. We capture it on initState so the
  /// teardown in dispose has a stable handle (re-reading the provider
  /// after the State is detached would throw).
  AcademicYearProvider? _academicYearProvider;

  @override
  void initState() {
    super.initState();
    _academicYearProvider = ref.read(academicYearRiverpod);
    _academicYearProvider!.addListener(_onAcademicYearChangedInternal);
  }

  @override
  void dispose() {
    _academicYearProvider?.removeListener(_onAcademicYearChangedInternal);
    super.dispose();
  }

  /// The currently-selected academic year ID as a String, or null
  /// when no year is selected yet (e.g. during first-load).
  String? get currentAcademicYearId {
    final id = ref.read(academicYearRiverpod).selectedAcademicYear?['id'];
    return id?.toString();
  }

  /// True when the user has navigated to a past / archived AY. The
  /// host screen typically uses this to hide FABs, disable Save
  /// buttons, or show a "Read-only" banner.
  bool get isAcademicYearReadOnly => ref.read(academicYearRiverpod).isReadOnly;

  /// Called whenever the dashboard academic-year selection changes.
  /// Implementers usually call their `_loadData()` here.
  void onAcademicYearChanged();

  void _onAcademicYearChangedInternal() {
    if (!mounted) return;
    onAcademicYearChanged();
  }
}
