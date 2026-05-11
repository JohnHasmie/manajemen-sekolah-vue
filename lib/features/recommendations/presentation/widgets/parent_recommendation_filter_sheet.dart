// Frame F from the parent Rekomendasi mockup — the filter sheet shown
// when the parent taps the filter icon on the rec list. Built on the
// shared AppFilterBottomSheet + FilterChipGrid components so the
// chrome (gradient header, Reset/Terapkan footer, safe-area padding)
// matches the rest of the app.
//
// Filters supported:
//   • Status — semua / belum dibaca / aktif / selesai
//   • Prioritas — semua / tinggi / sedang / rendah
//   • Mata Pelajaran — multi-select chip strip seeded from the rec
//     list's distinct subjects (so we never show a filter for a mapel
//     the parent doesn't have)
//   • Periode — 7 hari / 30 hari / semua
//
// The sheet pops with a [ParentRecFilter] on Terapkan, or null when
// the parent backs out / taps the scrim.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';

/// Status buckets exposed to the parent. The mapping back to recipient
/// rows lives in the screen state — we keep the enum simple here so
/// the filter chip labels stay short.
enum ParentRecStatus { all, unread, active, completed }

/// Priority buckets. `all` is the no-op default.
enum ParentRecPriority { all, high, medium, low }

/// Period buckets — drives a `sent_at >= now - X` cutoff.
enum ParentRecPeriod { last7, last30, all }

/// Snapshot of the parent's chosen filters. Immutable so the screen
/// state can compare values cheaply when deciding whether to refetch.
class ParentRecFilter {
  final ParentRecStatus status;
  final ParentRecPriority priority;

  /// Selected mata pelajaran names (lower-case for case-insensitive
  /// matching against rec.subjectSchool.name). Empty = no filter.
  final Set<String> subjects;

  final ParentRecPeriod period;

  const ParentRecFilter({
    this.status = ParentRecStatus.all,
    this.priority = ParentRecPriority.all,
    this.subjects = const <String>{},
    this.period = ParentRecPeriod.all,
  });

  /// Whether any non-default filter is active. Drives the "n aktif"
  /// header chip.
  int get activeCount {
    var n = 0;
    if (status != ParentRecStatus.all) n++;
    if (priority != ParentRecPriority.all) n++;
    if (subjects.isNotEmpty) n++;
    if (period != ParentRecPeriod.all) n++;
    return n;
  }

  ParentRecFilter copyWith({
    ParentRecStatus? status,
    ParentRecPriority? priority,
    Set<String>? subjects,
    ParentRecPeriod? period,
  }) {
    return ParentRecFilter(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      subjects: subjects ?? this.subjects,
      period: period ?? this.period,
    );
  }
}

/// Static helper — opens the filter sheet seeded from [current] and
/// returns the new [ParentRecFilter] on Terapkan, or null on cancel.
///
/// [availableSubjects] should be the distinct list of mata pelajaran
/// names present in the parent's inbox (case-preserved). The screen
/// derives this once per fetch and passes it in so the chip grid only
/// shows mapel the parent actually has recs for.
Future<ParentRecFilter?> showParentRecommendationFilterSheet({
  required BuildContext context,
  required ParentRecFilter current,
  required List<String> availableSubjects,
}) {
  return showFilterSheet<ParentRecFilter>(
    context: context,
    title: 'Filter Rekomendasi',
    primaryColor: ColorUtils.brandAzure,
    onApply: () {}, // wired inside the body so it can read current state
    onReset: () {}, // ditto
    content: _ParentRecFilterBody(
      initial: current,
      availableSubjects: availableSubjects,
    ),
  );
}

class _ParentRecFilterBody extends StatefulWidget {
  final ParentRecFilter initial;
  final List<String> availableSubjects;

  const _ParentRecFilterBody({
    required this.initial,
    required this.availableSubjects,
  });

  @override
  State<_ParentRecFilterBody> createState() => _ParentRecFilterBodyState();
}

class _ParentRecFilterBodyState extends State<_ParentRecFilterBody> {
  late ParentRecStatus _status;
  late ParentRecPriority _priority;
  late Set<String> _subjects;
  late ParentRecPeriod _period;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _priority = widget.initial.priority;
    _subjects = Set<String>.from(widget.initial.subjects);
    _period = widget.initial.period;
  }

  void _reset() {
    setState(() {
      _status = ParentRecStatus.all;
      _priority = ParentRecPriority.all;
      _subjects = <String>{};
      _period = ParentRecPeriod.all;
    });
  }

  void _apply() {
    AppNavigator.pop(
      context,
      ParentRecFilter(
        status: _status,
        priority: _priority,
        subjects: _subjects,
        period: _period,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final azure = ColorUtils.brandAzure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChipGrid<ParentRecStatus>(
          title: 'Status',
          selectedColor: azure,
          selectedValue: _status,
          options: const [
            FilterOption(value: ParentRecStatus.all, label: 'Semua'),
            FilterOption(value: ParentRecStatus.unread, label: 'Belum Dibaca'),
            FilterOption(value: ParentRecStatus.active, label: 'Aktif'),
            FilterOption(value: ParentRecStatus.completed, label: 'Selesai'),
          ],
          onSelected: (v) => setState(() => _status = v ?? ParentRecStatus.all),
        ),
        const SizedBox(height: 16),
        FilterChipGrid<ParentRecPriority>(
          title: 'Prioritas',
          selectedColor: azure,
          selectedValue: _priority,
          options: const [
            FilterOption(value: ParentRecPriority.all, label: 'Semua'),
            FilterOption(value: ParentRecPriority.high, label: 'Tinggi'),
            FilterOption(value: ParentRecPriority.medium, label: 'Sedang'),
            FilterOption(value: ParentRecPriority.low, label: 'Rendah'),
          ],
          onSelected: (v) =>
              setState(() => _priority = v ?? ParentRecPriority.all),
        ),
        if (widget.availableSubjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          FilterChipGrid<String>(
            title: 'Mata Pelajaran',
            selectedColor: azure,
            multiSelect: true,
            selectedValues: _subjects,
            options: widget.availableSubjects
                .map((s) => FilterOption(value: s, label: s))
                .toList(),
            onMultiSelected: (s) => setState(() => _subjects = s),
          ),
        ],
        const SizedBox(height: 16),
        FilterChipGrid<ParentRecPeriod>(
          title: 'Periode',
          selectedColor: azure,
          selectedValue: _period,
          options: const [
            FilterOption(value: ParentRecPeriod.last7, label: '7 Hari'),
            FilterOption(value: ParentRecPeriod.last30, label: '30 Hari'),
            FilterOption(value: ParentRecPeriod.all, label: 'Semua'),
          ],
          onSelected: (v) => setState(() => _period = v ?? ParentRecPeriod.all),
        ),
        const SizedBox(height: 18),
        // The sheet's own footer already hosts Reset/Apply buttons via
        // the AppFilterBottomSheet wrapper, BUT we need them wired to
        // *our* state, not the empty closures the helper accepted.
        // Render an inline mirror that mutates state and pops with the
        // result, and the parent helper's footer is left as decorative
        // because we pop manually before its onApply ever fires.
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorUtils.slate700,
                  side: BorderSide(color: ColorUtils.slate200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: azure,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Terapkan Filter',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
