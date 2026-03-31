// Unit tests for TeacherGradeController — covers pure state-mutation methods
// and the state/params models that have no external side-effects.
//
// Like testing a Laravel wizard controller's step transitions: we only assert
// what the controller does to in-memory state, not API calls.
//
// Controller is obtained via a ProviderContainer with an override that seeds
// the initial state, bypassing the real build() which calls the network.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal teacher map used as the family arg throughout tests.
final _teacher = <String, dynamic>{'id': 'T1', 'role': 'guru'};

/// Builds a seeded [TeacherGradeParams] for the family provider.
TeacherGradeParams get _params => TeacherGradeParams(teacher: _teacher);

/// Controller subclass that skips the real network-calling build().
class _SeededController extends TeacherGradeController {
  final TeacherGradeState seed;
  _SeededController(super.arg, this.seed);

  @override
  FutureOr<TeacherGradeState> build() => seed;
}

/// Creates a [ProviderContainer] seeded with [seed] and waits for it to load.
Future<ProviderContainer> _container(TeacherGradeState seed) async {
  final c = ProviderContainer(
    overrides: [
      teacherGradeProvider(_params).overrideWith(
        () => _SeededController(_params, seed),
      ),
    ],
  );
  await c.read(teacherGradeProvider(_params).future);
  return c;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── TeacherGradeState defaults ───────────────────────────────────────────

  group('TeacherGradeState defaults', () {
    const s = TeacherGradeState();

    test('currentStep is 0 (Class List)', () => expect(s.currentStep, 0));
    test('classList is empty', () => expect(s.classList, isEmpty));
    test('subjectList is empty', () => expect(s.subjectList, isEmpty));
    test('todaySchedules is empty', () => expect(s.todaySchedules, isEmpty));
    test('selectedClass is null', () => expect(s.selectedClass, isNull));
    test('selectedSubject is null', () => expect(s.selectedSubject, isNull));
    test('isLoading is true', () => expect(s.isLoading, isTrue));
    test('isLoadingMore is false', () => expect(s.isLoadingMore, isFalse));
    test('hasMoreData is true', () => expect(s.hasMoreData, isTrue));
    test('currentPage is 1', () => expect(s.currentPage, 1));
    test('searchQuery is empty string', () => expect(s.searchQuery, ''));
  });

  group('TeacherGradeState.copyWith', () {
    test('replaces only the specified fields', () {
      const original = TeacherGradeState(currentStep: 0, searchQuery: 'foo');
      final updated = original.copyWith(currentStep: 1);
      expect(updated.searchQuery, 'foo');
      expect(updated.currentStep, 1);
    });

    test('selectedClass and selectedSubject are independent', () {
      final classData = {'id': 'C1', 'name': '7A'};
      final subjectData = {'id': 'S1', 'name': 'Math'};
      const s = TeacherGradeState();
      final s1 = s.copyWith(selectedClass: classData);
      final s2 = s1.copyWith(selectedSubject: subjectData);
      expect(s2.selectedClass, classData);
      expect(s2.selectedSubject, subjectData);
    });
  });

  // ── TeacherGradeParams equality ──────────────────────────────────────────

  group('TeacherGradeParams equality', () {
    test('two params with same teacher id are equal', () {
      final a = TeacherGradeParams(teacher: {'id': 'T1', 'name': 'Alice'});
      final b = TeacherGradeParams(teacher: {'id': 'T1', 'name': 'Bob'});
      expect(a, equals(b));
    });

    test('two params with different teacher id are not equal', () {
      final a = TeacherGradeParams(teacher: {'id': 'T1'});
      final b = TeacherGradeParams(teacher: {'id': 'T2'});
      expect(a, isNot(equals(b)));
    });

    test('hashCode is the same when ids match', () {
      final a = TeacherGradeParams(teacher: {'id': 'T42'});
      final b = TeacherGradeParams(teacher: {'id': 'T42'});
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when ids differ', () {
      final a = TeacherGradeParams(teacher: {'id': 'T1'});
      final b = TeacherGradeParams(teacher: {'id': 'T2'});
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('identical instance equals itself', () {
      final p = TeacherGradeParams(teacher: {'id': 'T1'});
      expect(p, equals(p));
    });
  });

  // ── setStep ──────────────────────────────────────────────────────────────

  group('setStep', () {
    test('advances currentStep to 1 (Subject List)', () async {
      final c = await _container(const TeacherGradeState(currentStep: 0, isLoading: false));
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).setStep(1);

      expect(c.read(teacherGradeProvider(_params)).value?.currentStep, 1);
    });

    test('sets currentStep back to 0 (Class List)', () async {
      final c = await _container(const TeacherGradeState(currentStep: 1, isLoading: false));
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).setStep(0);

      expect(c.read(teacherGradeProvider(_params)).value?.currentStep, 0);
    });

    test('preserves other state fields when changing step', () async {
      final seed = TeacherGradeState(
        currentStep: 0,
        classList: [{'id': 'C1'}],
        searchQuery: 'test',
        isLoading: false,
      );
      final c = await _container(seed);
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).setStep(1);

      final state = c.read(teacherGradeProvider(_params)).value!;
      expect(state.classList, hasLength(1));
      expect(state.searchQuery, 'test');
    });
  });

  // ── selectSubject ────────────────────────────────────────────────────────

  group('selectSubject', () {
    final subjectData = {'id': 'S1', 'name': 'Mathematics', 'can_edit': true};

    test('sets selectedSubject in state', () async {
      final c = await _container(const TeacherGradeState(currentStep: 1, isLoading: false));
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).selectSubject(subjectData);

      expect(c.read(teacherGradeProvider(_params)).value?.selectedSubject, subjectData);
    });

    test('does not change currentStep', () async {
      final c = await _container(const TeacherGradeState(currentStep: 1, isLoading: false));
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).selectSubject(subjectData);

      expect(c.read(teacherGradeProvider(_params)).value?.currentStep, 1);
    });

    test('replacing selection overwrites the previous value', () async {
      final first = {'id': 'S1', 'name': 'Math'};
      final second = {'id': 'S2', 'name': 'Physics'};
      final seed = TeacherGradeState(selectedSubject: first, isLoading: false);
      final c = await _container(seed);
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).selectSubject(second);

      expect(c.read(teacherGradeProvider(_params)).value?.selectedSubject?['id'], 'S2');
    });
  });

  // ── updateSearch — sync state flip ───────────────────────────────────────

  group('updateSearch (sync state flip)', () {
    test('searchQuery is updated synchronously before network call', () async {
      final seed = const TeacherGradeState(
        currentStep: 1, // Subject step → no _loadClasses call
        isLoading: false,
      );
      final c = await _container(seed);
      addTearDown(c.dispose);

      // Step 1 does NOT call _loadClasses, so this is network-free
      await c.read(teacherGradeProvider(_params).notifier).updateSearch('algebra');

      expect(c.read(teacherGradeProvider(_params)).value?.searchQuery, 'algebra');
    });

    test('currentPage resets to 1 on new search', () async {
      final seed = const TeacherGradeState(
        currentStep: 1,
        currentPage: 3,
        isLoading: false,
      );
      final c = await _container(seed);
      addTearDown(c.dispose);

      await c.read(teacherGradeProvider(_params).notifier).updateSearch('science');

      expect(c.read(teacherGradeProvider(_params)).value?.currentPage, 1);
    });
  });
}
