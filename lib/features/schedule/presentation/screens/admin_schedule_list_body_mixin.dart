// List-view body builder + day/time helpers for the admin Jadwal hub.
//
// Extracted from `admin_schedule_management_screen.dart` during the
// Phase-2 readability split. These methods are tightly coupled to the
// screen state's private fields (`_selectedIds`, `_activeDayTab`,
// `_dayList`, `_availableDays`, `_focusedDayId`, …) and private methods
// (`_toggleSelection`, `_showScheduleDetail`, `_buildEmptyListCard`), so
// they live in a `part` file that shares the screen library's private
// scope rather than a standalone mixin with accessor boilerplate.
//
// Behaviour is unchanged — every method is moved verbatim; only its
// physical home changed.
part of 'admin_schedule_management_screen.dart';

/// List-view rendering + List-mode day/time helpers for
/// [TeachingScheduleManagementScreenState].
///
/// Splits the day-tab pill strip, per-day Pagi/Siang sectioning, flat
/// fallback renderer, and the supporting day/time math out of the main
/// state class. Declared as an extension in the same library (via the
/// `part` directive) so it reads the state's private fields and methods
/// directly without accessor boilerplate.
extension _AdminScheduleListBody on TeachingScheduleManagementScreenState {
  /// Renders the List view body — day-tab pill row + (per-day) Pagi /
  /// Siang sections of row cards. Tap a tab to client-filter to that
  /// day; tap the active tab again to clear back to "Semua".
  ///
  /// Day-tab filtering is purely client-side so it doesn't trigger a
  /// new API hit; the underlying `filteredSchedules` already respects
  /// the server-side filter chips (Periode / Hari / Kelas / Jam) +
  /// search.
  List<Widget> _buildListBody({
    required List<dynamic> filteredSchedules,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
    required Color primaryColor,
  }) {
    // ── 1. Compute visible weekdays (Senin → Sabtu) ────────────────
    final visibleDays = _visibleListDays();
    if (visibleDays.isEmpty) {
      // No day reference data loaded yet — render a plain list as a
      // fallback. Should be rare in practice; _loadFilterOptions fires
      // alongside _loadSchedules.
      return _buildFlatRowCards(
        items: filteredSchedules,
        lang: lang,
        ctrl: ctrl,
      );
    }

    // ── 2. Count schedules per day for tab badges ─────────────────
    final countsByDay = <String, int>{};
    for (final s in filteredSchedules) {
      if (s is! Map) continue;
      final dayId = s['day_id']?.toString();
      if (dayId == null) continue;
      countsByDay[dayId] = (countsByDay[dayId] ?? 0) + 1;
    }

    // ── 3. Apply day-tab client filter on top of server filter ────
    final List<dynamic> tabFiltered = _activeDayTab == null
        ? filteredSchedules
        : filteredSchedules
              .where(
                (s) => s is Map && s['day_id']?.toString() == _activeDayTab,
              )
              .toList(growable: false);

    final widgets = <Widget>[
      // Day-tab pill strip.
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AdminScheduleDayTabStrip(
          days: visibleDays,
          selectedDayId: _activeDayTab,
          countsByDay: countsByDay,
          onChanged: _setActiveDayTab,
        ),
      ),
    ];

    if (tabFiltered.isEmpty) {
      widgets.add(_buildEmptyListCard(lang));
      return widgets;
    }

    // ── 4. Group by day_id → Pagi / Siang sub-sections ─────────────
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final s in tabFiltered) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final dayId = m['day_id']?.toString();
      if (dayId == null) continue;
      byDay.putIfAbsent(dayId, () => []).add(m);
    }

    // Render in visibleDays order so days always appear Senin → Sabtu
    // regardless of how the API ordered the rows.
    for (final day in visibleDays) {
      final dayId = day['id']?.toString();
      final rows = byDay[dayId] ?? const [];
      if (rows.isEmpty) continue;

      // Day-section header is only shown when "Semua" is selected; in
      // single-day mode the day tab itself is the header.
      if (_activeDayTab == null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              (day['name'] ?? '').toString().toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandDarkBlue,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );
      }

      // Sort rows by start_time ascending so Pagi → Siang reads
      // naturally inside each section.
      rows.sort((a, b) {
        final aMin = _parseStartMinutes(a) ?? 99999;
        final bMin = _parseStartMinutes(b) ?? 99999;
        return aMin.compareTo(bMin);
      });

      final pagi = <Map<String, dynamic>>[];
      final siang = <Map<String, dynamic>>[];
      for (final row in rows) {
        final start = _parseStartMinutes(row) ?? 0;
        // Cutoff: 12:00 — adjust if some schools want a different
        // morning/afternoon split.
        if (start < 12 * 60) {
          pagi.add(row);
        } else {
          siang.add(row);
        }
      }

      if (pagi.isNotEmpty) {
        widgets.addAll(_buildSection('Pagi', pagi, ctrl, lang));
      }
      if (siang.isNotEmpty) {
        widgets.addAll(_buildSection('Siang', siang, ctrl, lang));
      }
    }

    return widgets;
  }

  /// Renders one Pagi/Siang section — kicker header + N row cards.
  List<Widget> _buildSection(
    String label,
    List<Map<String, dynamic>> rows,
    AdminScheduleController ctrl,
    LanguageProvider lang,
  ) {
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: AdminScheduleSectionHead(label: label, count: rows.length),
      ),
    ];
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      final id = m['id']?.toString() ?? '';
      final isSelected = _selectedIds.contains(id);
      final startTime = (m['start_time'] ?? '').toString();
      final endTime = (m['end_time'] ?? '').toString();
      final duration = _formatDuration(m);
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 6 : 8, 16, 0),
          child: AdminScheduleRowCard(
            schedule: m,
            startTimeLabel: startTime,
            endTimeLabel: endTime,
            durationLabel: duration,
            subjectName:
                (m['subject_name'] ?? m['mata_pelajaran_nama'] ?? 'No Subject')
                    .toString(),
            className: (m['class_name'] ?? m['kelas_nama'] ?? '').toString(),
            teacherName: (m['teacher_name'] ?? m['guru_nama'] ?? '').toString(),
            roomName: (m['room'] ?? m['ruangan'] ?? '').toString(),
            selected: isSelected,
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _showScheduleDetail(m),
            onLongPress: () => _toggleSelection(id),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Fallback flat-row renderer when the [_dayList] reference data
  /// isn't loaded yet (e.g. very first paint). Skips tabs + sections
  /// and just lists each schedule with the new row card.
  List<Widget> _buildFlatRowCards({
    required List<dynamic> items,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
  }) {
    if (items.isEmpty) return [_buildEmptyListCard(lang)];
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i] is! Map) continue;
      final m = Map<String, dynamic>.from(items[i] as Map);
      final id = m['id']?.toString() ?? '';
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 6 : 8, 16, 0),
          child: AdminScheduleRowCard(
            schedule: m,
            startTimeLabel: (m['start_time'] ?? '').toString(),
            endTimeLabel: (m['end_time'] ?? '').toString(),
            durationLabel: _formatDuration(m),
            subjectName:
                (m['subject_name'] ?? m['mata_pelajaran_nama'] ?? 'No Subject')
                    .toString(),
            className: (m['class_name'] ?? m['kelas_nama'] ?? '').toString(),
            teacherName: (m['teacher_name'] ?? m['guru_nama'] ?? '').toString(),
            roomName: (m['room'] ?? m['ruangan'] ?? '').toString(),
            selected: _selectedIds.contains(id),
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _showScheduleDetail(m),
            onLongPress: () => _toggleSelection(id),
          ),
        ),
      );
    }
    return widgets;
  }

  // ── List-mode helpers ──────────────────────────────────────────────

  /// Returns today's day_id from the loaded day list, or null when
  /// today is Sunday (Minggu is filtered out of the school week) or
  /// the day data hasn't loaded yet. Drives the default focused day
  /// in the Grid view.
  String? _todayDayId() {
    final source = _dayList.isNotEmpty ? _dayList : _availableDays;
    final now = DateTime.now();
    for (final d in source) {
      if (d is! Map) continue;
      final order = (d['order_number'] as num?)?.toInt();
      if (order == now.weekday) return d['id']?.toString();
    }
    return null;
  }

  /// Seeds [_focusedDayId] to today's day_id the first time the day
  /// list becomes available, so the Grid view opens zoomed in on
  /// today by default. After the initial seed the admin's pick wins
  /// — re-entering the screen doesn't reset their last focus.
  void _maybeSeedFocusedDay() {
    if (_focusedDaySeeded) return;
    final today = _todayDayId();
    if (today != null) {
      _focusedDayId = today;
      _focusedDaySeeded = true;
    }
  }

  /// Returns the visible weekdays (Senin → Sabtu) sorted by
  /// order_number. Minggu (order 7 or 0) is filtered out.
  List<Map<String, dynamic>> _visibleListDays() {
    final source = _dayList.isNotEmpty ? _dayList : _availableDays;
    final mapped = source
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    mapped.removeWhere((d) {
      final order = d['order_number'];
      if (order is num) return order == 7 || order == 0;
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name == 'sunday' || name == 'minggu';
    });
    mapped.sort((a, b) {
      final ao = (a['order_number'] as num?)?.toInt() ?? 99;
      final bo = (b['order_number'] as num?)?.toInt() ?? 99;
      return ao.compareTo(bo);
    });
    return mapped;
  }

  /// Parses a schedule row's `start_time` into total minutes from
  /// midnight. Returns null when the field is missing / malformed.
  int? _parseStartMinutes(Map<String, dynamic> schedule) {
    final raw = (schedule['start_time'] ?? '').toString();
    if (raw.isEmpty) return null;
    final parts = raw.replaceAll('.', ':').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Formats a session's duration in minutes (e.g. "90 mnt") by
  /// diffing start_time and end_time. Returns null when either field
  /// is missing so the row card can hide the duration label entirely.
  String? _formatDuration(Map<String, dynamic> schedule) {
    final start = _parseStartMinutes(schedule);
    final endRaw = (schedule['end_time'] ?? '').toString();
    if (start == null || endRaw.isEmpty) return null;
    final endParts = endRaw.replaceAll('.', ':').split(':');
    if (endParts.length < 2) return null;
    final eh = int.tryParse(endParts[0]);
    final em = int.tryParse(endParts[1]);
    if (eh == null || em == null) return null;
    final end = eh * 60 + em;
    final diff = end - start;
    if (diff <= 0) return null;
    return '$diff mnt';
  }

  // ── Body rendering per view mode ──────────────────────────────────
  //
  // Returns a flat list of widgets to splice into BrandPageLayout's
  // bodyChildren. Each mode renders its own structure:
  //   - grid:   "Coming soon" placeholder card (TR.A.2 fills in)
  //   - list:   Loading / error / empty / N cards + tap-to-load-more
  //   - matrix: AdminScheduleMatrixView wrapped at a fixed height
  List<Widget> _buildViewBody({
    required ScheduleViewMode mode,
    required List<dynamic> filteredSchedules,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
    required Color primaryColor,
    required bool isReadOnly,
  }) {
    if (_isLoading && _scheduleList.isEmpty) {
      // Skeleton picks the right shape for the active view mode so the
      // silhouette matches the data that's about to appear. Grid/Matrix
      // get the week-grid ghost; List gets the row-card ghost.
      return [
        if (mode == ScheduleViewMode.list)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ScheduleListSkeleton(),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ScheduleGridSkeleton(),
          ),
      ];
    }
    if (_errorMessage != null) {
      return [
        AdminScheduleErrorCard(message: _errorMessage!, onRetry: _onRefresh),
      ];
    }

    switch (mode) {
      case ScheduleViewMode.grid:
        // Week-grid calendar. Renders schedules as color-coded blocks
        // on a Mon-Sab × time grid. Tap a block → detail sheet.
        // Long-press-and-drag (TR.E.1) lets the admin move a session
        // onto a different slot; the drop fires [_handleReschedule]
        // which PATCHes the row's lesson_hour_days_id server-side.
        //
        // Drag drops are disabled when the current academic year is
        // read-only — passing `null` to [onReschedule] makes the grid
        // skip the LongPressDraggable wrapping so blocks stay tappable
        // but un-draggable.
        return [
          AdminScheduleWeekGridView(
            scheduleList: filteredSchedules,
            dayList: _dayList.isNotEmpty ? _dayList : _availableDays,
            lessonHourList: _lessonHourList,
            highlightDayId: _selectedDayId,
            // In bulk mode the screen routes block taps through
            // _toggleSelection (parity with list rows). Outside bulk
            // mode taps open the detail sheet as before. The grid's
            // own block-render layer flips behaviour based on
            // [isBulkMode] / [selectedIds], so the screen just hands
            // it both callbacks.
            onScheduleTap: _showScheduleDetail,
            onScheduleLongPress: isReadOnly
                ? null
                : (s) {
                    final id = s['id']?.toString();
                    if (id != null && id.isNotEmpty) _toggleSelection(id);
                  },
            // Drag-drop is auto-suppressed inside the grid when
            // [isBulkMode] is true, so we don't need to gate the
            // reschedule callback here.
            onReschedule: isReadOnly ? null : _handleReschedule,
            selectedIds: _selectedIds,
            // Density-mode hooks — 6+ session clusters open the slot
            // expansion sheet on tap and seed bulk-select on long-press.
            onSlotClusterTap: _openSlotClusterSheet,
            onSlotClusterLongPress: isReadOnly ? null : _selectClusterForBulk,
            // Zoom-in day view — default to today on first load, allow
            // the admin to tap a day-header cell (week mode) or any
            // pill (focused mode) to switch days, swipe horizontally
            // to navigate, and tap the grid icon to zoom out.
            focusedDayId: _focusedDayId,
            onFocusedDayChanged: _setFocusedDayId,
          ),
        ];

      case ScheduleViewMode.matrix:
        // Wrap matrix view at a fixed-ish height so it sits cleanly
        // inside BrandPageLayout's outer ListView. The matrix has its
        // own horizontal scroll inside the FrozenColumnTable.
        return [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: AdminScheduleMatrixView(
              scheduleList: filteredSchedules,
              dayList: _dayList.isNotEmpty ? _dayList : _availableDays,
              lessonHourList: _lessonHourList,
              selectedDayId: _selectedDayId,
              selectedLessonHour: _selectedLessonHour,
              primaryColor: primaryColor,
              languageProvider: lang,
              onScheduleTap: _showScheduleDetail,
            ),
          ),
        ];

      case ScheduleViewMode.list:
        return _buildListBody(
          filteredSchedules: filteredSchedules,
          lang: lang,
          ctrl: ctrl,
          primaryColor: primaryColor,
        );
    }
  }

  /// Renders the empty-state card shown when the list (or any view
  /// mode) has zero schedules.
  ///
  /// Three flavours (TR.H):
  ///   * **Pristine empty** — no filters, no day tab, search cleared,
  ///     AY editable. Shows the "Belum ada jadwal" hero + dual CTAs
  ///     (Tambah Manual + Import Excel) so the admin can start
  ///     populating data right from the empty state without having to
  ///     find the FAB or hunt down the overflow menu.
  ///   * **Filter-empty** — at least one filter active or a day-tab
  ///     selected. Shows the "Tidak ada hasil" copy + a single
  ///     secondary button to clear filters. Hides the data-entry CTAs
  ///     because the issue is filtering, not lack of data.
  ///   * **Read-only AY** — admin is browsing a past academic year.
  ///     Shows the "Belum ada jadwal di tahun ajaran ini" copy with
  ///     no write CTAs (would 403 anyway), just a read-only pill so
  ///     it's clear the absence is intentional, not a missing import.
  Widget _buildEmptyListCard(LanguageProvider lang) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final hasFilters =
        _hasActiveFilter ||
        _activeDayTab != null ||
        _searchController.text.isNotEmpty;
    return AdminScheduleEmptyCard(
      lang: lang,
      isReadOnly: isReadOnly,
      hasFilters: hasFilters,
      onClearFilters: _clearAllFilters,
      onImportExcel: _importFromExcel,
      onAddManually: _openAddEditSheet,
    );
  }
}
