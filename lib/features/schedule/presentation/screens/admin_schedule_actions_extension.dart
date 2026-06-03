// Mutation actions for the admin Jadwal hub — single-row move / change-
// teacher, drag-and-drop reschedule engine, and the bulk move / change-
// teacher / delete handlers.
//
// Extracted from `admin_schedule_management_screen.dart` during the
// Phase-2 readability split. Declared as an extension in the same library
// (via the `part` directive) so it reads the state's private fields and
// methods directly. The `setState`-touching primitives it depends on
// (`_setRescheduleBanner`, `_clearSelectedIds`) stay on the state class
// because extensions can't call the protected `setState`. Behaviour is
// unchanged — every method is moved verbatim.
part of 'admin_schedule_management_screen.dart';

/// Mutation actions for [TeachingScheduleManagementScreenState] — the
/// per-row, drag-drop, and bulk write paths.
extension _AdminScheduleActions on TeachingScheduleManagementScreenState {
  /// "Pindah Slot" handler — opens the day picker and bulk-moves this
  /// single row to the equivalent lesson_hour on the target day.
  ///
  /// Reuses [showBulkDayPickerSheet] + [ApiScheduleService.bulkMoveSessions]
  /// with a one-element id list so the List view's per-row Pindah Slot
  /// single row to the target day AND hour.
  ///
  /// Reuses [_doReschedule] so it has the same UX as drag-and-drop
  /// (including the "Urungkan" action and "Paksa Simpan" conflict toast).
  Future<void> _moveSlotForSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null || id.isEmpty) return;

    final visibleDays = _visibleListDays();
    final targetLessonHourDaysId = await showSingleRescheduleSheet(
      context: context,
      schedule: schedule,
      days: visibleDays,
      lessonHours: _lessonHourList,
      semesterId: _selectedTerm,
      academicYearId: _selectedAcademicYear,
      languageProvider: ref.read(languageRiverpod),
    );

    if (targetLessonHourDaysId == null || !mounted) return;

    // The sheet returns the specific lesson_hour_days_id. We need to
    // find the corresponding day name and start time for the success toast.
    final targetHourData = _lessonHourList.firstWhere(
      (h) => h['id']?.toString() == targetLessonHourDaysId,
      orElse: () => const <String, dynamic>{},
    );

    final targetDayId =
        targetHourData['day_id']?.toString() ??
        targetHourData['hari_id']?.toString();
    final dayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == targetDayId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    final startTime =
        (targetHourData['start_time'] ?? targetHourData['jam_mulai'] ?? '')
            .toString();

    final previousLessonHourId =
        schedule['lesson_hour_days_id']?.toString() ?? '';
    final previousDayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == schedule['day_id']?.toString(),
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';
    final previousStartTime = (schedule['start_time'] ?? '').toString();

    final subjectName =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();

    await _doReschedule(
      scheduleId: id,
      targetLessonHourId: targetLessonHourDaysId,
      targetDayName: dayName,
      targetStartTime: startTime,
      subjectName: subjectName,
      previousLessonHourId: previousLessonHourId,
      previousDayName: previousDayName,
      previousStartTime: previousStartTime,
      force: false,
    );
  }

  /// "Ganti Guru" per-row handler — opens the teacher picker and
  /// reassigns this single row to the selected teacher. Mirrors the
  /// bulk flow with a single id.
  Future<void> _changeTeacherForSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null || id.isEmpty) return;
    final teachers = _availableTeachers
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final teacherId = await showBulkTeacherPickerSheet(
      context: context,
      teachers: teachers,
      selectedCount: 1,
    );
    if (teacherId == null || !mounted) return;
    final teacherName =
        teachers
            .firstWhere(
              (t) => t['id']?.toString() == teacherId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';
    await _runBulkChangeTeacher(
      ids: [id],
      teacherId: teacherId,
      teacherName: teacherName,
      force: false,
    );
  }

  // ── Drag-and-drop reschedule (Frame E.1 + E.2) ──────────────────────

  /// Drag-and-drop reschedule entry point — wired into the grid view's
  /// [AdminScheduleWeekGridView.onReschedule] callback. Fires when an
  /// admin long-press-drags a session block onto a different day/slot
  /// in the week-grid view.
  ///
  /// Looks up the previous + new day names for nicer toast copy and
  /// delegates to [_doReschedule]. The schedule map is the original
  /// (pre-move) API row passed via the drag payload — used to capture
  /// the rollback slot for Urungkan (TR.E.2).
  Future<void> _handleReschedule({
    required Map<String, dynamic> schedule,
    required String newLessonHourDaysId,
    required String newDayId,
    required String newStartTime,
  }) async {
    final scheduleId = schedule['id']?.toString();
    if (scheduleId == null || scheduleId.isEmpty) return;

    String resolveDayName(String? id) {
      if (id == null || id.isEmpty) return '';
      return _availableDays
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (d) => d['id']?.toString() == id,
                orElse: () => const {'name': ''},
              )['name']
              ?.toString() ??
          '';
    }

    final newDayName = resolveDayName(newDayId);
    final previousLessonHourId =
        schedule['lesson_hour_days_id']?.toString() ?? '';
    final previousDayName = resolveDayName(schedule['day_id']?.toString());
    final previousStartTime = (schedule['start_time'] ?? '').toString();
    final subjectName =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();

    await _doReschedule(
      scheduleId: scheduleId,
      targetLessonHourId: newLessonHourDaysId,
      targetDayName: newDayName,
      targetStartTime: newStartTime,
      subjectName: subjectName,
      previousLessonHourId: previousLessonHourId,
      previousDayName: previousDayName,
      previousStartTime: previousStartTime,
      force: false,
    );
  }

  /// Internal reschedule worker — issues the PATCH and surfaces the
  /// appropriate toast for the outcome.
  ///
  /// Three terminal states:
  ///   * **Success** → green snack with the target slot and an
  ///     "URUNGKAN" action that calls back into this method with the
  ///     target / previous slot ids swapped (and `force: true`, so the
  ///     rollback can't be blocked by another row racing in).
  ///   * **409 conflict** → red snack with the server's `error` body
  ///     and a "PAKSA SIMPAN" action that retries the same drop with
  ///     `force: true`. Server-side force=true accepts the duplicate
  ///     and lets the admin clean up after.
  ///   * **Any other error** → plain red snack via [SnackBarUtils.showError].
  ///
  /// `previousLessonHourId` is allowed to be empty (and the Urungkan
  /// action is then suppressed) for callers that don't have access to
  /// a rollback slot — e.g. an admin who refreshes the list mid-undo.
  /// Pulls the most actionable error string out of a [DioException].
  ///
  /// Priority: 409 conflict's `conflicts[].message` (says which side
  /// is blocked) → top-level `error` → top-level `message` → null.
  /// Used by the banner to show a short reason without re-implementing
  /// the same extraction inside the catch block below.
  String? _extractServerMessage(DioException e) {
    final body = e.response?.data;
    if (body is! Map) return null;
    if (e.response?.statusCode == 409 && body['conflicts'] is List) {
      for (final c in body['conflicts'] as List) {
        if (c is Map && c['message'] is String) {
          return c['message'] as String;
        }
      }
    }
    if (body['error'] is String) return body['error'] as String;
    if (body['message'] is String) return body['message'] as String;
    return null;
  }

  Future<void> _doReschedule({
    required String scheduleId,
    required String targetLessonHourId,
    required String targetDayName,
    required String targetStartTime,
    required String subjectName,
    required String previousLessonHourId,
    required String previousDayName,
    required String previousStartTime,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);

    // Compose the slot labels surfaced in the banner. Falls back to
    // an em-dash when either side is empty (e.g. an Urungkan that
    // doesn't carry the rollback day name).
    String fmtSlot(String day, String time) {
      final d = day.trim();
      final t = time.trim();
      if (d.isEmpty && t.isEmpty) return '—';
      if (d.isEmpty) return t;
      if (t.isEmpty) return d;
      return '$d · $t';
    }

    _setRescheduleBanner(
      ScheduleRescheduleSnapshot(
        subjectName: subjectName,
        fromSlotLabel: fmtSlot(previousDayName, previousStartTime),
        toSlotLabel: fmtSlot(targetDayName, targetStartTime),
        phase: ScheduleReschedulePhase.loading,
      ),
    );

    try {
      await getIt<ApiScheduleService>().rescheduleSession(
        scheduleId: scheduleId,
        lessonHourDaysId: targetLessonHourId,
        force: force,
      );
      if (!mounted) return;
      // Flip the banner to success the moment the server confirms —
      // before the list refresh — so the admin sees the green tick
      // even on slow networks where _loadSchedules adds a beat. The
      // banner auto-dismisses 1.4s later regardless of refresh state.
      _setRescheduleBanner(
        _rescheduleBanner?.copyWith(phase: ScheduleReschedulePhase.success),
        autoDismiss: const Duration(milliseconds: 1400),
      );
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      // Only offer Urungkan when we know where to roll back to and
      // the rollback would actually move the row (rules out no-op
      // drops onto the source slot, which the grid filters anyway).
      final canUndo =
          previousLessonHourId.isNotEmpty &&
          previousLessonHourId != targetLessonHourId;

      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en': 'Moved "$subjectName" to $targetDayName $targetStartTime',
          'id':
              'Sesi "$subjectName" dipindah ke '
              '$targetDayName $targetStartTime',
        }),
        backgroundColor: ColorUtils.success600,
        duration: const Duration(seconds: 5),
        actions: [
          if (canUndo)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'UNDO',
                'id': 'URUNGKAN',
              }),
              onTap: () => _doReschedule(
                scheduleId: scheduleId,
                // Swap target ↔ previous so the call rolls back.
                targetLessonHourId: previousLessonHourId,
                targetDayName: previousDayName,
                targetStartTime: previousStartTime,
                subjectName: subjectName,
                previousLessonHourId: targetLessonHourId,
                previousDayName: targetDayName,
                previousStartTime: targetStartTime,
                // Force so a race-in row can't block the undo.
                force: true,
              ),
            ),
        ],
      );
    } on DioException catch (e) {
      AppLogger.error(
        'schedule',
        'reschedule failed: ${e.response?.statusCode} ${e.message} '
            'body=${e.response?.data}',
      );
      if (!mounted) return;
      // Flip the banner to error before extracting the message — gives
      // an instant red signal even before the snackbar fires. The
      // banner sticks around until the snackbar dismisses (longer
      // auto-dismiss tolerates the reader checking what went wrong).
      _setRescheduleBanner(
        _rescheduleBanner?.copyWith(
          phase: ScheduleReschedulePhase.error,
          errorMessage: _extractServerMessage(e),
        ),
        autoDismiss: const Duration(seconds: 5),
      );
      // Extract the server's structured `error` / `message` field
      // before falling back to ErrorUtils. Backend may surface a
      // 422 "lesson_hour_days_id invalid" / 500 "no slot at this
      // day" etc. — those messages are actionable, so we want them
      // verbatim instead of the generic "Terjadi kesalahan sistem".
      // For 409s, [_extractServerMessage] already prefers the first
      // conflict's `message` over the top-level `error` so the admin
      // sees "Guru sudah punya jadwal" instead of the generic
      // "Slot bentrok" — no extra conflict lookup needed here.
      final serverMsg = _extractServerMessage(e);

      // 409 = teacher / class collision. Falls back to a built-in
      // copy if the body shape is unexpected.
      if (e.response?.statusCode == 409) {
        SnackBarUtils.showWithActions(
          context,
          message:
              serverMsg ??
              lang.getTranslatedText({
                'en': 'Slot $targetDayName $targetStartTime is already taken.',
                'id': 'Slot $targetDayName $targetStartTime sudah terisi.',
              }),
          backgroundColor: ColorUtils.error600,
          duration: const Duration(seconds: 6),
          actions: [
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _doReschedule(
                scheduleId: scheduleId,
                targetLessonHourId: targetLessonHourId,
                targetDayName: targetDayName,
                targetStartTime: targetStartTime,
                subjectName: subjectName,
                previousLessonHourId: previousLessonHourId,
                previousDayName: previousDayName,
                previousStartTime: previousStartTime,
                force: true,
              ),
            ),
          ],
        );
        return;
      }
      // Non-409 — prefer the server's error message when present,
      // otherwise fall back to the generic friendly translator.
      final prefix = lang.getTranslatedText(const {
        'en': 'Failed to reschedule: ',
        'id': 'Gagal memindahkan: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${serverMsg ?? ErrorUtils.getFriendlyMessage(e)}',
      );
      // The backend has been observed to 500 *after* committing the
      // update (e.g. notify-step failure). Force a refresh so the UI
      // re-syncs with whatever actually landed in the DB instead of
      // showing stale data after a misleading error toast.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      final prefix = lang.getTranslatedText(const {
        'en': 'Failed to reschedule: ',
        'id': 'Gagal memindahkan: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
      );
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final lang = ref.read(languageRiverpod);
    final selected = _scheduleList
        .cast<Map<String, dynamic>>()
        .where((s) => _selectedIds.contains(s['id']?.toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: lang.getTranslatedText(const {
        'en': 'sessions',
        'id': 'sesi',
      }),
      items: selected
          .map(
            (s) => BulkDeleteItem(
              id: s['id'].toString(),
              title: (s['subject_name'] ?? '?').toString(),
              subtitle: [
                s['class_name'],
                s['teacher_name'],
              ].where((v) => v != null && v.toString().isNotEmpty).join(' · '),
            ),
          )
          .toList(),
    );
    if (ok != true || !mounted) return;

    final ids = selected
        .map((s) => s['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final total = ids.length;
    _clearSelectedIds();

    try {
      final deleted = await getIt<ApiScheduleService>().bulkDeleteSessions(ids);
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': '$deleted of $total sessions deleted',
          'id': '$deleted dari $total sesi terhapus',
        }),
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk delete failed: $e');
      if (!mounted) return;
      final prefix = lang.getTranslatedText(const {
        'en': 'Bulk delete failed: ',
        'id': 'Hapus massal gagal: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// "Pindah Hari" bulk action — opens the day picker, then bulk-moves
  /// every selected session to the equivalent lesson_hour on the target
  /// day (server preserves hour_number).
  ///
  /// Skipped rows surface in a red toast with **PAKSA SIMPAN** that
  /// retries those ids with `force: true` — same UX as the single-row
  /// drag reschedule's 409 path so the flow feels consistent.
  Future<void> _bulkMoveSelected() async {
    if (_selectedIds.isEmpty) return;
    final visibleDays = _visibleListDays();
    final ids = _selectedIds.toList(growable: false);
    final total = ids.length;

    final targetDayId = await showBulkDayPickerSheet(
      context: context,
      days: visibleDays,
      selectedCount: total,
    );
    if (targetDayId == null || !mounted) return;

    final dayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == targetDayId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    await _runBulkMove(
      ids: ids,
      targetDayId: targetDayId,
      targetDayName: dayName,
      force: false,
    );
    if (!mounted) return;
    _clearSelectedIds();
  }

  /// Internal bulk-move worker. Separated so the **PAKSA SIMPAN** retry
  /// action can call back with `force: true` on the same payload without
  /// re-opening the picker.
  Future<void> _runBulkMove({
    required List<String> ids,
    required String targetDayId,
    required String targetDayName,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);
    try {
      final result = await getIt<ApiScheduleService>().bulkMoveSessions(
        ids: ids,
        targetDayId: targetDayId,
        force: force,
      );
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      final movedCount = (result['moved_count'] is num)
          ? (result['moved_count'] as num).toInt()
          : 0;
      final skipped = (result['skipped'] is List)
          ? List<dynamic>.from(result['skipped'] as List)
          : const <dynamic>[];

      if (skipped.isEmpty) {
        SnackBarUtils.showSuccess(
          context,
          lang.getTranslatedText({
            'en':
                '$movedCount of ${ids.length} sessions moved to '
                '$targetDayName',
            'id':
                '$movedCount dari ${ids.length} sesi dipindah ke '
                '$targetDayName',
          }),
        );
        return;
      }

      // Some rows hit conflicts. Offer Paksa simpan to force the
      // remaining ids through.
      final skippedIds = skipped
          .whereType<Map>()
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en': '$movedCount moved, ${skipped.length} skipped (conflicts).',
          'id': '$movedCount dipindah, ${skipped.length} dilewati (bentrok).',
        }),
        backgroundColor: ColorUtils.error600,
        duration: const Duration(seconds: 7),
        actions: [
          if (skippedIds.isNotEmpty)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _runBulkMove(
                ids: skippedIds,
                targetDayId: targetDayId,
                targetDayName: targetDayName,
                force: true,
              ),
            ),
        ],
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk move failed: $e');
      if (!mounted) return;
      final prefix = lang.getTranslatedText(const {
        'en': 'Bulk move failed: ',
        'id': 'Pindah massal gagal: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
      );
      // The backend has been observed to 500 *after* committing the
      // update (e.g. notify-step failure). Force a refresh so the UI
      // re-syncs with whatever actually landed in the DB instead of
      // showing stale data after a misleading error toast.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
  }

  /// "Ganti Guru" bulk action — opens the teacher picker, then bulk-
  /// reassigns every selected row to the chosen teacher_id.
  ///
  /// Skipped rows (teacher already has a colliding slot) surface in the
  /// same Paksa simpan toast pattern as bulk move.
  Future<void> _bulkChangeTeacherForSelected() async {
    if (_selectedIds.isEmpty) return;
    final teachers = _availableTeachers
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final ids = _selectedIds.toList(growable: false);
    final total = ids.length;

    final teacherId = await showBulkTeacherPickerSheet(
      context: context,
      teachers: teachers,
      selectedCount: total,
    );
    if (teacherId == null || !mounted) return;

    final teacherName =
        teachers
            .firstWhere(
              (t) => t['id']?.toString() == teacherId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    await _runBulkChangeTeacher(
      ids: ids,
      teacherId: teacherId,
      teacherName: teacherName,
      force: false,
    );
    if (!mounted) return;
    _clearSelectedIds();
  }

  /// Internal bulk change-teacher worker — mirrors [_runBulkMove] so the
  /// PAKSA SIMPAN action can recurse on the skipped subset with
  /// `force: true`.
  Future<void> _runBulkChangeTeacher({
    required List<String> ids,
    required String teacherId,
    required String teacherName,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);
    try {
      final result = await getIt<ApiScheduleService>().bulkChangeTeacher(
        ids: ids,
        teacherId: teacherId,
        force: force,
      );
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      final movedCount = (result['moved_count'] is num)
          ? (result['moved_count'] as num).toInt()
          : 0;
      final skipped = (result['skipped'] is List)
          ? List<dynamic>.from(result['skipped'] as List)
          : const <dynamic>[];

      if (skipped.isEmpty) {
        SnackBarUtils.showSuccess(
          context,
          lang.getTranslatedText({
            'en':
                '$movedCount of ${ids.length} sessions assigned to '
                '$teacherName',
            'id':
                '$movedCount dari ${ids.length} sesi dialihkan ke '
                '$teacherName',
          }),
        );
        return;
      }

      final skippedIds = skipped
          .whereType<Map>()
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en':
              '$movedCount reassigned, ${skipped.length} skipped (conflicts).',
          'id': '$movedCount dialihkan, ${skipped.length} dilewati (bentrok).',
        }),
        backgroundColor: ColorUtils.error600,
        duration: const Duration(seconds: 7),
        actions: [
          if (skippedIds.isNotEmpty)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _runBulkChangeTeacher(
                ids: skippedIds,
                teacherId: teacherId,
                teacherName: teacherName,
                force: true,
              ),
            ),
        ],
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk change teacher failed: $e');
      if (!mounted) return;
      final prefix = lang.getTranslatedText(const {
        'en': 'Bulk change teacher failed: ',
        'id': 'Ganti guru massal gagal: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
      );
      // Same "500-after-commit" refresh pattern as bulk move — see
      // _runBulkMove for the rationale.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
  }

  // ── Print PDF ───────────────────────────────────────────────────────

  /// Opens the Print PDF scope picker; once admin chooses a scope,
  /// calls the backend `/teaching-schedule/print-pdf` endpoint with the
  /// currently-applied filters and the chosen scope. Snackbar feedback
  /// is handled inside [SchedulePrintPdfService.printAndShow] so the
  /// screen stays thin.
  void _openPrintPdfSheet() {
    // Compose a one-line summary of active filters so admin sees the
    // PDF will mirror the visible list. The labels reuse the same
    // resolvers as the BrandFilterChip strip.
    final lang = ref.read(languageRiverpod);
    final parts = <String>[];
    String? teacherLabel;
    if (_selectedTeacherId != null) {
      final m = _availableTeachers.cast<Map<String, dynamic>>().firstWhere(
        (t) => t['id']?.toString() == _selectedTeacherId,
        orElse: () => const {'name': null},
      );
      teacherLabel = (m['name'] ?? m['nama'])?.toString();
      if (teacherLabel != null) parts.add('Guru $teacherLabel');
    }
    String? subjectLabel;
    if (_selectedSubjectId != null) {
      final m = _subjectList.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id']?.toString() == _selectedSubjectId,
        orElse: () => const {'name': null},
      );
      subjectLabel = (m['name'] ?? m['nama'])?.toString();
      if (subjectLabel != null) parts.add('Mapel $subjectLabel');
    }
    if (_selectedClassId != null) {
      final m = _availableClasses.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id']?.toString() == _selectedClassId,
        orElse: () => const {'name': null},
      );
      final classLabel = (m['name'] ?? m['nama'])?.toString();
      if (classLabel != null) parts.add('Kelas $classLabel');
    }
    if (_selectedDayId != null) {
      final m = _availableDays.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['id']?.toString() == _selectedDayId,
        orElse: () => const {'name': null},
      );
      final dayLabel = (m['name'] ?? m['nama'])?.toString();
      if (dayLabel != null) parts.add('Hari $dayLabel');
    }
    if (_selectedLessonHour != null) {
      parts.add('Jam $_selectedLessonHour');
    }
    final activeFilterPrefix = lang.getTranslatedText(const {
      'en': 'Active filter: ',
      'id': 'Filter aktif: ',
    });
    final summary = parts.isEmpty
        ? lang.getTranslatedText(const {
            'en': 'No filters active — full timetable.',
            'id': 'Tanpa filter — seluruh jadwal akan dicetak.',
          })
        : '$activeFilterPrefix${parts.join(' · ')}';

    SchedulePrintScopeSheet.show(
      context: context,
      filterSummary: summary,
      onConfirm: (scope) async {
        await SchedulePrintPdfService.printAndShow(
          context: context,
          scope: scope,
          teacherId: _selectedTeacherId,
          subjectId: _selectedSubjectId,
          classId: _selectedClassId,
          dayId: _selectedDayId,
          hourNumber: _selectedLessonHour,
          semesterId: _selectedFilterTerm ?? _selectedTerm,
          academicYearId: _selectedAcademicYear,
        );
      },
    );
  }
}
