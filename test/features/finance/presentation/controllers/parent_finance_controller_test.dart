// Unit tests for ParentFinanceController — covers state-mutation logic
// that can be exercised without hitting the network or cache.
//
// Like testing a Laravel Controller's in-memory state transformations:
// we inject a known starting state and assert the outcome.
//
// Uses a [_SeededParentFinanceController] subclass to bypass the real
// build() which calls external APIs.  The production DI path is still
// exercised because we override via [parentFinanceProvider.overrideWith].
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_state.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [Student] for test use.
Student _student({String id = 's1', String name = 'Ali'}) => Student(
  id: id,
  name: name,
  className: '7A',
  studentNumber: 'NIS001',
  address: '',
  guardianName: '',
  phoneNumber: '',
);

/// Builds a minimal billing item map matching the API response shape.
Map<String, dynamic> _bill({
  String id = 'b1',
  bool isRead = false,
  String status = 'unpaid',
  String name = 'SPP Januari',
}) => {'id': id, 'is_read': isRead, 'status': status, 'name': name};

/// Controller subclass that skips the real network-calling build().
/// Initialises immediately with a caller-supplied [ParentFinanceState].
class _SeededParentFinanceController extends ParentFinanceController {
  final ParentFinanceState seed;
  _SeededParentFinanceController(this.seed);

  @override
  FutureOr<ParentFinanceState> build() => seed;
}

/// Creates a [ProviderContainer] pre-seeded with [seed] and awaits the state.
Future<ProviderContainer> _container(ParentFinanceState seed) async {
  final c = ProviderContainer(
    overrides: [
      parentFinanceProvider.overrideWith(
        () => _SeededParentFinanceController(seed),
      ),
    ],
  );
  await c.read(parentFinanceProvider.future);
  return c;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── ParentFinanceState defaults ──────────────────────────────────────────

  group('ParentFinanceState defaults', () {
    const s = ParentFinanceState();

    test('students starts as empty list', () => expect(s.students, isEmpty));
    test(
      'billingItems starts as empty list',
      () => expect(s.billingItems, isEmpty),
    );
    test('isLoading starts as true', () => expect(s.isLoading, isTrue));
    test(
      'processedReadIds starts as empty set',
      () => expect(s.processedReadIds, isEmpty),
    );
    test(
      'pendingReadIds starts as empty set',
      () => expect(s.pendingReadIds, isEmpty),
    );
    test('searchQuery starts as empty string', () => expect(s.searchQuery, ''));
    test('statusFilter starts as null', () => expect(s.statusFilter, isNull));
    test('periodFilter starts as null', () => expect(s.periodFilter, isNull));
  });

  group('ParentFinanceState.copyWith', () {
    test('replaces only the specified fields', () {
      const original = ParentFinanceState(searchQuery: 'foo', isLoading: false);
      final updated = original.copyWith(statusFilter: 'unpaid');
      expect(updated.searchQuery, 'foo');
      expect(updated.isLoading, isFalse);
      expect(updated.statusFilter, 'unpaid');
    });

    test('processedReadIds and pendingReadIds are independent', () {
      const original = ParentFinanceState();
      final s1 = original.copyWith(processedReadIds: {'a'});
      final s2 = s1.copyWith(pendingReadIds: {'b'});
      expect(s2.processedReadIds, {'a'});
      expect(s2.pendingReadIds, {'b'});
    });
  });

  // ── markItemVisible ──────────────────────────────────────────────────────

  group('markItemVisible', () {
    late ParentFinanceState seed;

    setUp(() {
      seed = ParentFinanceState(
        selectedStudent: _student(),
        billingItems: [
          _bill(id: 'b1'),
          _bill(id: 'b2'),
        ],
        isLoading: false,
      );
    });

    test(
      'adds id to processedReadIds when item is unread and unseen',
      () async {
        final c = await _container(seed);
        addTearDown(c.dispose);

        c.read(parentFinanceProvider.notifier).markItemVisible('b1', false);
        // markItemVisible now defers the state mutation to a microtask;
        // flush it before asserting.
        await Future<void>.microtask(() {});

        final state = c.read(parentFinanceProvider).value!;
        expect(state.processedReadIds, contains('b1'));
      },
    );

    test('adds id to pendingReadIds when item is unread and unseen', () async {
      final c = await _container(seed);
      addTearDown(c.dispose);

      c.read(parentFinanceProvider.notifier).markItemVisible('b1', false);
      await Future<void>.microtask(() {});

      final state = c.read(parentFinanceProvider).value!;
      expect(state.pendingReadIds, contains('b1'));
    });

    test(
      'is a no-op when isRead is true (server already marked it read)',
      () async {
        final c = await _container(seed);
        addTearDown(c.dispose);

        c.read(parentFinanceProvider.notifier).markItemVisible('b1', true);

        final state = c.read(parentFinanceProvider).value!;
        expect(state.processedReadIds, isEmpty);
        expect(state.pendingReadIds, isEmpty);
      },
    );

    test('is a no-op when id already in processedReadIds', () async {
      final seenSeed = seed.copyWith(processedReadIds: {'b1'});
      final c = await _container(seenSeed);
      addTearDown(c.dispose);

      c.read(parentFinanceProvider.notifier).markItemVisible('b1', false);

      final state = c.read(parentFinanceProvider).value!;
      // pendingReadIds should still be empty (no re-schedule)
      expect(state.pendingReadIds, isEmpty);
    });

    test('accumulates multiple unseen ids independently', () async {
      final c = await _container(seed);
      addTearDown(c.dispose);
      final notifier = c.read(parentFinanceProvider.notifier);

      notifier.markItemVisible('b1', false);
      notifier.markItemVisible('b2', false);
      // Flush the per-call microtasks that apply the deferred mutations.
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      final state = c.read(parentFinanceProvider).value!;
      expect(state.processedReadIds, containsAll(['b1', 'b2']));
      expect(state.pendingReadIds, containsAll(['b1', 'b2']));
    });

    test(
      'does not duplicate ids when called twice for the same item',
      () async {
        final c = await _container(seed);
        addTearDown(c.dispose);
        final notifier = c.read(parentFinanceProvider.notifier);

        notifier.markItemVisible('b1', false);
        await Future<void>.microtask(() {});
        notifier.markItemVisible('b1', false); // second call is a no-op
        await Future<void>.microtask(() {});

        final state = c.read(parentFinanceProvider).value!;
        // Set semantics: still exactly one entry
        expect(state.processedReadIds.where((id) => id == 'b1'), hasLength(1));
      },
    );
  });

  // ── processedReadIds / pendingReadIds Set semantics ─────────────────────

  group('processedReadIds Set semantics', () {
    test('copyWith with Set spread deduplicates correctly', () {
      const s = ParentFinanceState();
      final s1 = s.copyWith(processedReadIds: {'a', 'b'});
      final s2 = s1.copyWith(
        processedReadIds: {...s1.processedReadIds, 'b', 'c'},
      );
      // Set dedup: 'b' appears once
      expect(s2.processedReadIds, {'a', 'b', 'c'});
      expect(s2.processedReadIds.length, 3);
    });

    test('pendingReadIds cleared independently of processedReadIds', () {
      const s = ParentFinanceState();
      final pending = s.copyWith(
        processedReadIds: {'x', 'y'},
        pendingReadIds: {'x', 'y'},
      );
      final cleared = pending.copyWith(pendingReadIds: {});
      expect(cleared.processedReadIds, {'x', 'y'});
      expect(cleared.pendingReadIds, isEmpty);
    });

    test('processedReadIds.contains correctly identifies seen ids', () {
      const s = ParentFinanceState();
      final withIds = s.copyWith(processedReadIds: {'bill-42'});
      expect(withIds.processedReadIds.contains('bill-42'), isTrue);
      expect(withIds.processedReadIds.contains('bill-99'), isFalse);
    });
  });
}
