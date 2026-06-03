/// Pre-fetched roster of filter chip options for the active user.
///
/// **Brand filter rule** — every filter sheet in the app gets its
/// class / subject / teacher / day / semester chip options from this
/// provider. Filter sheets must NOT derive chip options from the
/// page's currently-displayed list (`_groupedData`, paginated lists,
/// etc.) — that list is server-filtered and will collapse the chip
/// set the moment a filter is applied, trapping the user.
///
/// Hydration model — the provider is hydrated once during dashboard
/// init (alongside `/dashboard/full`) by calling
/// `FilterOptionsService.getFilterOptions(role, academicYearId)`,
/// which hits the role-aware `GET /filter-options` endpoint. The
/// response is cached for 6 hours by `FilterOptionsService` (via
/// `LocalCacheService`); `hydrate()` reads through that cache, so
/// re-mounts after warm boot don't re-hit the network.
///
/// For teachers, the backend's `role=guru` branch returns the
/// teacher's *scoped* roster (homeroom + teaching_schedule +
/// grade-authored, deduped) plus a pre-partitioned split into
/// `teaching_classes` and `homeroom_classes`. Filter sheets that
/// surface the wali ↔ mengajar dichotomy pick the appropriate
/// list via [classesForView].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart' as riverpod_legacy;

import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Snapshot of pre-fetched filter rosters for the active user.
///
/// All getters return empty lists when the provider hasn't hydrated
/// yet — call sites should fall back to skeleton / empty state
/// rather than crashing on cold open.
class FilterRosterProvider extends ChangeNotifier {
  // The currently-hydrated scope. Used to short-circuit `hydrate()`
  // when the same (role, ay) combination is requested twice.
  String? _role;
  String? _academicYearId;

  List<dynamic> _classes = const [];
  List<dynamic> _teachingClasses = const [];
  List<dynamic> _homeroomClasses = const [];
  List<dynamic> _subjects = const [];
  List<dynamic> _teachingSubjects = const [];
  List<dynamic> _homeroomSubjects = const [];
  List<dynamic> _teachers = const [];
  List<dynamic> _days = const [];
  List<dynamic> _semesters = const [];
  List<dynamic> _academicYears = const [];

  // class_id → [subject_id, ...] direct map from the backend.
  Map<String, List<String>> _classSubjectsByClass = const {};
  Map<String, List<String>> _teachingClassSubjects = const {};
  Map<String, List<String>> _homeroomClassSubjects = const {};
  // subject_id → [class_id, ...] inverse, computed once on hydrate
  // so the FE doesn't recompute on every chip render.
  Map<String, List<String>> _classesBySubject = const {};
  Map<String, List<String>> _teachingClassesBySubject = const {};
  Map<String, List<String>> _homeroomClassesBySubject = const {};

  bool _isLoaded = false;
  bool _isLoading = false;
  Object? _lastError;

  String? get role => _role;
  String? get academicYearId => _academicYearId;

  /// Full class roster for the active user.
  /// - admin: every class in the school
  /// - guru:  the teacher's scoped union (homeroom + teaching + graded)
  /// - wali:  empty (parent filters don't surface a class chip set)
  List<dynamic> get classes => _classes;

  /// Teacher-only: classes the user *teaches* (is_homeroom=false).
  /// Empty for other roles.
  List<dynamic> get teachingClasses => _teachingClasses;

  /// Teacher-only: classes the user is wali kelas of (is_homeroom=true).
  /// Empty for other roles.
  List<dynamic> get homeroomClasses => _homeroomClasses;

  /// Subjects across the user's roster. For teachers this is the
  /// global "every subject I ever touch" set — for the per-class
  /// narrow set use the per-class fetch (`/teacher/{id}/subjects?
  /// class_id=...`) since that's a different question.
  List<dynamic> get subjects => _subjects;

  List<dynamic> get teachers => _teachers;
  List<dynamic> get days => _days;
  List<dynamic> get semesters => _semesters;
  List<dynamic> get academicYears => _academicYears;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  /// Returns the class chip set appropriate for the active teacher
  /// view. Pass `isHomeroomView: true` from screens that toggle
  /// between mengajar and wali kelas (Nilai, Presensi, Materi,
  /// Kegiatan Kelas, Rekap Nilai) so the wali view shows only the
  /// homeroom and mengajar view shows the full teaching set.
  ///
  /// For non-teacher roles this just returns [classes].
  List<dynamic> classesForView({required bool isHomeroomView}) {
    if (_role != 'guru') return _classes;
    return isHomeroomView ? _homeroomClasses : _teachingClasses;
  }

  /// Cross-axis lookup — the subjects available for [classId].
  ///
  /// - `classId == null` → returns the global [subjects] roster (no
  ///   class picked yet, so any subject is fair game).
  /// - `classId` set → returns the subset of [subjects] that the
  ///   backend mapped to this class (`class_subjects[classId]`).
  ///
  /// Replaces the on-tap `GET /teacher/{id}/subjects?class_id=X`
  /// round-trip every filter mixin used to fire on chip select. The
  /// chip set updates synchronously inside the same `setSS`.
  List<dynamic> subjectsForClass(
    String? classId, {
    bool isHomeroomView = false,
  }) {
    final useTeaching = _role == 'guru' && !isHomeroomView;
    final subjectsSource = useTeaching
        ? (_teachingSubjects.isNotEmpty ? _teachingSubjects : _subjects)
        : (_role == 'guru' && isHomeroomView && _homeroomSubjects.isNotEmpty
              ? _homeroomSubjects
              : _subjects);

    final mapSource = useTeaching
        ? (_teachingClassSubjects.isNotEmpty
              ? _teachingClassSubjects
              : _classSubjectsByClass)
        : (_role == 'guru' &&
                  isHomeroomView &&
                  _homeroomClassSubjects.isNotEmpty
              ? _homeroomClassSubjects
              : _classSubjectsByClass);

    if (classId == null || classId.isEmpty) return subjectsSource;
    final allowed = mapSource[classId];
    if (allowed == null || allowed.isEmpty) {
      // No mapping for this class — fall back to the global roster
      // so the sheet isn't empty (e.g. a class that doesn't yet
      // appear in the map because of a cold-state edge case).
      return subjectsSource;
    }
    final allowedSet = allowed.toSet();
    return subjectsSource
        .where((s) {
          if (s is! Map) return false;
          return allowedSet.contains(s['id']?.toString());
        })
        .toList(growable: false);
  }

  /// Cross-axis lookup — the classes that teach [subjectId].
  ///
  /// - `subjectId == null` → returns [classesForView] for the active
  ///   teacher view, or the full [classes] roster for non-teachers.
  /// - `subjectId` set → intersects that with classes mapped to
  ///   this subject.
  ///
  /// Used to narrow the Kelas chip set when the user picked a
  /// subject first.
  List<dynamic> classesForSubject(
    String? subjectId, {
    bool isHomeroomView = false,
  }) {
    final base = classesForView(isHomeroomView: isHomeroomView);
    if (subjectId == null || subjectId.isEmpty) return base;

    final useTeaching = _role == 'guru' && !isHomeroomView;
    final mapSource = useTeaching
        ? (_teachingClassesBySubject.isNotEmpty
              ? _teachingClassesBySubject
              : _classesBySubject)
        : (_role == 'guru' &&
                  isHomeroomView &&
                  _homeroomClassesBySubject.isNotEmpty
              ? _homeroomClassesBySubject
              : _classesBySubject);

    final allowed = mapSource[subjectId];
    if (allowed == null || allowed.isEmpty) return base;
    final allowedSet = allowed.toSet();
    return base
        .where((c) {
          if (c is! Map) return false;
          return allowedSet.contains(c['id']?.toString());
        })
        .toList(growable: false);
  }

  /// Returns the entire `class_subjects` map. Exposed for callers
  /// that need direct access (admin attendance report builds its
  /// own multi-select chip arrangement); most mixins should use
  /// [subjectsForClass] / [classesForSubject] instead.
  Map<String, List<String>> get classSubjectsByClass => _classSubjectsByClass;
  Map<String, List<String>> get classesBySubject => _classesBySubject;

  /// Hydrates the provider for (role, academicYearId). No-op when
  /// already hydrated for the same scope (use [refresh] to bust the
  /// in-memory state).
  ///
  /// Reads through `FilterOptionsService`'s 6h cache, so repeated
  /// calls within the TTL are free.
  Future<void> hydrate({required String role, String? academicYearId}) async {
    if (_isLoaded && _role == role && _academicYearId == academicYearId) {
      return;
    }
    return _load(role: role, academicYearId: academicYearId, force: false);
  }

  /// Force a fresh fetch — used on academic year change, on admin
  /// mutations that affect rosters (via `CacheInvalidationService`),
  /// and on pull-to-refresh of the dashboard.
  Future<void> refresh({required String role, String? academicYearId}) {
    return _load(role: role, academicYearId: academicYearId, force: true);
  }

  /// Clears the in-memory snapshot. Called on logout / school
  /// switch so the next login starts with a clean roster.
  void clear() {
    _role = null;
    _academicYearId = null;
    _classes = const [];
    _teachingClasses = const [];
    _homeroomClasses = const [];
    _subjects = const [];
    _teachingSubjects = const [];
    _homeroomSubjects = const [];
    _teachers = const [];
    _days = const [];
    _semesters = const [];
    _academicYears = const [];
    _classSubjectsByClass = const {};
    _teachingClassSubjects = const {};
    _homeroomClassSubjects = const {};
    _classesBySubject = const {};
    _teachingClassesBySubject = const {};
    _homeroomClassesBySubject = const {};
    _isLoaded = false;
    _isLoading = false;
    _lastError = null;
    notifyListeners();
  }

  Future<void> _load({
    required String role,
    String? academicYearId,
    required bool force,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final data = force
          ? await FilterOptionsService.refreshFilterOptions(
              role: role,
              academicYearId: academicYearId,
            )
          : await FilterOptionsService.getFilterOptions(
              role: role,
              academicYearId: academicYearId,
            );

      _role = role;
      _academicYearId = academicYearId;
      _classes = _asList(data['classes']);
      _teachingClasses = _asList(data['teaching_classes']);
      _homeroomClasses = _asList(data['homeroom_classes']);
      _subjects = _asList(data['subjects']);
      _teachingSubjects = _asList(data['teaching_subjects']);
      _homeroomSubjects = _asList(data['homeroom_subjects']);
      _teachers = _asList(data['teachers']);
      _days = _asList(data['days']);
      _semesters = _asList(data['semesters']);
      _academicYears = _asList(data['academic_years']);
      _classSubjectsByClass = _asStringListMap(data['class_subjects']);
      _teachingClassSubjects = _asStringListMap(
        data['teaching_class_subjects'],
      );
      _homeroomClassSubjects = _asStringListMap(
        data['homeroom_class_subjects'],
      );
      _classesBySubject = _invertMap(_classSubjectsByClass);
      _teachingClassesBySubject = _invertMap(_teachingClassSubjects);
      _homeroomClassesBySubject = _invertMap(_homeroomClassSubjects);
      _isLoaded = true;
    } catch (e, st) {
      AppLogger.error('filter-roster', 'hydrate failed: $e\n$st');
      _lastError = e;
      // Don't wipe whatever was previously loaded — better to show
      // a stale chip set than nothing at all.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<dynamic> _asList(dynamic v) {
    if (v is List) return List<dynamic>.from(v);
    return const [];
  }

  /// Coerces a backend `class_subjects` payload into the typed
  /// shape we work with. Accepts the canonical
  /// `{classId: [subjectId, ...]}` form and is tolerant of stray
  /// non-string values (cast to String, drop nulls).
  Map<String, List<String>> _asStringListMap(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, List<String>>{};
    v.forEach((key, value) {
      final k = key?.toString();
      if (k == null || k.isEmpty) return;
      if (value is! Iterable) return;
      final ids = <String>[];
      for (final item in value) {
        final s = item?.toString();
        if (s != null && s.isNotEmpty) ids.add(s);
      }
      if (ids.isNotEmpty) out[k] = ids;
    });
    return out;
  }

  /// Inverts `classSubjectsByClass` to `subjectId → [classId, ...]`
  /// once on hydrate so the cross-axis Kelas lookup is O(1) in the
  /// number of classes teaching a subject, not O(n) over the whole
  /// map.
  Map<String, List<String>> _invertMap(Map<String, List<String>> src) {
    final out = <String, List<String>>{};
    src.forEach((classId, subjectIds) {
      for (final subjectId in subjectIds) {
        (out[subjectId] ??= <String>[]).add(classId);
      }
    });
    return out;
  }
}

/// Riverpod handle for the singleton provider. Hydrate it from the
/// dashboard controller after login.
final filterRosterRiverpod =
    riverpod_legacy.ChangeNotifierProvider<FilterRosterProvider>(
      (ref) => FilterRosterProvider(),
    );
