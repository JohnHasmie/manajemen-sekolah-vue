// Consolidated Tagihan filter sheet.
//
// All filters live here (status / jenis / tahun / bulan / tingkat /
// kelas) so the Keuangan hub header only needs to render a single
// "Filter" chip + counter — no more side-by-side Status / Bulan /
// Jenis chips that don't compose. The matching ClassFinanceReport
// (per-kelas matrix) re-uses the same sheet by hiding the Kelas /
// Tingkat sections (it's already scoped to one kelas).
//
// Built on the shared [AppFilterBottomSheet] + [FilterChipGrid]
// primitives so the chrome (gradient header, scroll, Reset/Apply
// footer, safe-area handling) matches every other admin filter
// surface in the app.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
// Re-export the canonical TagihanStatusFilter enum so consumers can
// import this single file and get both the consolidated filter sheet
// + the enum it operates on. The enum itself lives in
// status_filter_sheet.dart where the legacy single-status picker also
// uses it — keeping a single source avoids the "imported from both"
// duplicate-symbol error we hit during the KU.3 migration.
export 'package:manajemensekolah/features/finance/presentation/widgets/status_filter_sheet.dart'
    show TagihanStatusFilter, TagihanStatusFilterX, tagihanStatusFromKey;
import 'package:manajemensekolah/features/finance/presentation/widgets/status_filter_sheet.dart';

/// Snapshot returned by the filter sheet.
class TagihanFilterResult {
  /// Top-level status — `all`, `unpaid` (belum + tempo), or `overdue`.
  final TagihanStatusFilter status;

  /// IDs of payment types to keep. Empty set means "all jenis".
  final Set<String> selectedJenisIds;

  /// Selected academic year (4-digit, e.g. `2025`). `null` = all years.
  final int? year;

  /// Selected month (1-12). `null` = all months.
  final int? month;

  /// Tingkat / grade-levels (string keys like `"7"`, `"8"`). Empty = all.
  final Set<String> selectedTingkat;

  /// Specific class IDs. Empty = all classes in the picked tingkat (or
  /// every class when tingkat is also empty).
  final Set<String> selectedClassIds;

  const TagihanFilterResult({
    this.status = TagihanStatusFilter.all,
    this.selectedJenisIds = const {},
    this.year,
    this.month,
    this.selectedTingkat = const {},
    this.selectedClassIds = const {},
  });

  /// Convenience helper — produces the empty / no-filter result.
  factory TagihanFilterResult.empty() => const TagihanFilterResult();

  /// Number of *active* filters — drives the "Filter (N)" counter
  /// chip on the page header. Status counts as 1 when not `all`.
  int get activeCount {
    var n = 0;
    if (status != TagihanStatusFilter.all) n++;
    if (selectedJenisIds.isNotEmpty) n++;
    if (year != null) n++;
    if (month != null) n++;
    if (selectedTingkat.isNotEmpty) n++;
    if (selectedClassIds.isNotEmpty) n++;
    return n;
  }

  bool get hasAny => activeCount > 0;

  TagihanFilterResult copyWith({
    TagihanStatusFilter? status,
    Set<String>? selectedJenisIds,
    int? year,
    int? month,
    Set<String>? selectedTingkat,
    Set<String>? selectedClassIds,
    bool clearYear = false,
    bool clearMonth = false,
  }) {
    return TagihanFilterResult(
      status: status ?? this.status,
      selectedJenisIds: selectedJenisIds ?? this.selectedJenisIds,
      year: clearYear ? null : (year ?? this.year),
      month: clearMonth ? null : (month ?? this.month),
      selectedTingkat: selectedTingkat ?? this.selectedTingkat,
      selectedClassIds: selectedClassIds ?? this.selectedClassIds,
    );
  }
}

/// Lightweight class option for the sheet — `{id, name, gradeLevel}`.
class TagihanClassOption {
  final String id;
  final String name;
  final String? gradeLevel;
  const TagihanClassOption({
    required this.id,
    required this.name,
    this.gradeLevel,
  });
}

/// Open the sheet. Returns the new [TagihanFilterResult] on Apply,
/// or `null` if the admin dismisses without applying.
Future<TagihanFilterResult?> showTagihanFilterSheet(
  BuildContext context, {
  required Color primaryColor,
  required List<Map<String, String>> jenisOptions,
  required List<TagihanClassOption> classOptions,
  required List<int> availableYears,
  required TagihanFilterResult initial,
  bool showClassSections = true,
}) {
  return showModalBottomSheet<TagihanFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TagihanFilterSheet(
      primaryColor: primaryColor,
      jenisOptions: jenisOptions,
      classOptions: classOptions,
      availableYears: availableYears,
      initial: initial,
      showClassSections: showClassSections,
    ),
  );
}

class _TagihanFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final List<Map<String, String>> jenisOptions;
  final List<TagihanClassOption> classOptions;
  final List<int> availableYears;
  final TagihanFilterResult initial;

  /// When false (per-kelas report context), the Tingkat + Kelas
  /// sections collapse — they're already scoped upstream.
  final bool showClassSections;

  const _TagihanFilterSheet({
    required this.primaryColor,
    required this.jenisOptions,
    required this.classOptions,
    required this.availableYears,
    required this.initial,
    required this.showClassSections,
  });

  @override
  State<_TagihanFilterSheet> createState() => _TagihanFilterSheetState();
}

class _TagihanFilterSheetState extends State<_TagihanFilterSheet> {
  late TagihanStatusFilter _status;
  late Set<String> _jenisIds;
  late int? _year;
  late int? _month;
  late Set<String> _tingkat;
  late Set<String> _classIds;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _jenisIds = Set.from(widget.initial.selectedJenisIds);
    _year = widget.initial.year;
    _month = widget.initial.month;
    _tingkat = Set.from(widget.initial.selectedTingkat);
    _classIds = Set.from(widget.initial.selectedClassIds);
  }

  /// Distinct, sorted grade-levels pulled out of the classOptions list.
  /// "7" before "10" via natural-numeric sort (strings would put 10 first).
  List<String> get _tingkatOptions {
    final set = <String>{};
    for (final c in widget.classOptions) {
      final lvl = c.gradeLevel?.trim();
      if (lvl != null && lvl.isNotEmpty) set.add(lvl);
    }
    final list = set.toList();
    list.sort((a, b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.compareTo(b);
    });
    return list;
  }

  /// Class list narrowed by the picked Tingkat (if any). When no
  /// tingkat is picked the full list shows.
  List<TagihanClassOption> get _visibleClasses {
    if (_tingkat.isEmpty) return widget.classOptions;
    return widget.classOptions
        .where((c) => _tingkat.contains(c.gradeLevel))
        .toList();
  }

  void _reset() {
    setState(() {
      _status = TagihanStatusFilter.all;
      _jenisIds = {};
      _year = null;
      _month = null;
      _tingkat = {};
      _classIds = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    final showClass = widget.showClassSections;

    return AppFilterBottomSheet(
      title: kFinFilterBills.tr,
      headerSubtitle:
          'Saring tagihan berdasarkan status, jenis, '
          'periode, tingkat, dan kelas.',
      icon: Icons.tune_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.90,
      onApply: () => AppNavigator.pop(
        context,
        TagihanFilterResult(
          status: _status,
          selectedJenisIds: Set.from(_jenisIds),
          year: _year,
          month: _month,
          selectedTingkat: Set.from(_tingkat),
          selectedClassIds: Set.from(_classIds),
        ),
      ),
      onReset: _reset,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChipGrid<TagihanStatusFilter>(
            title: kFinStatus.tr,
            options: [
              FilterOption(
                value: TagihanStatusFilter.all,
                label: kFinAll.tr,
                icon: Icons.all_inbox_rounded,
              ),
              FilterOption(
                value: TagihanStatusFilter.unpaid,
                label: kFinUnpaid.tr,
                icon: Icons.error_outline_rounded,
              ),
              FilterOption(
                value: TagihanStatusFilter.overdue,
                label: kFinDueDate.tr,
                icon: Icons.event_busy_rounded,
              ),
            ],
            selectedValue: _status,
            onSelected: (v) =>
                setState(() => _status = v ?? TagihanStatusFilter.all),
            selectedColor: navy,
          ),
          const SizedBox(height: 18),
          if (widget.jenisOptions.isNotEmpty) ...[
            FilterChipGrid<String>(
              title: kFinPaymentType.tr,
              multiSelect: true,
              options: [
                for (final j in widget.jenisOptions)
                  FilterOption(value: j['id'] ?? '', label: j['name'] ?? '-'),
              ],
              selectedValues: _jenisIds,
              onMultiSelected: (s) => setState(() => _jenisIds = s),
              selectedColor: navy,
            ),
            const SizedBox(height: 18),
          ],
          if (widget.availableYears.isNotEmpty) ...[
            FilterChipGrid<int>(
              title: kFinYearFilter.tr,
              options: [
                for (final y in widget.availableYears)
                  FilterOption(value: y, label: y.toString()),
              ],
              selectedValue: _year,
              onSelected: (v) => setState(() => _year = v),
              selectedColor: navy,
            ),
            const SizedBox(height: 18),
          ],
          FilterChipGrid<int>(
            title: kFinMonthFilter.tr,
            options: const [
              FilterOption(value: 1, label: 'Jan'),
              FilterOption(value: 2, label: 'Feb'),
              FilterOption(value: 3, label: 'Mar'),
              FilterOption(value: 4, label: 'Apr'),
              FilterOption(value: 5, label: 'Mei'),
              FilterOption(value: 6, label: 'Jun'),
              FilterOption(value: 7, label: 'Jul'),
              FilterOption(value: 8, label: 'Ags'),
              FilterOption(value: 9, label: 'Sep'),
              FilterOption(value: 10, label: 'Okt'),
              FilterOption(value: 11, label: 'Nov'),
              FilterOption(value: 12, label: 'Des'),
            ],
            selectedValue: _month,
            onSelected: (v) => setState(() => _month = v),
            selectedColor: navy,
          ),
          if (showClass && _tingkatOptions.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilterChipGrid<String>(
              title: kFinGradeLevel.tr,
              multiSelect: true,
              options: [
                for (final t in _tingkatOptions)
                  FilterOption(value: t, label: 'Kelas $t'),
              ],
              selectedValues: _tingkat,
              onMultiSelected: (s) => setState(() {
                _tingkat = s;
                // Drop class picks that no longer match the active
                // tingkat — keeps the result internally consistent.
                _classIds = _classIds.where((id) {
                  final c = widget.classOptions.firstWhere(
                    (o) => o.id == id,
                    orElse: () => const TagihanClassOption(id: '', name: ''),
                  );
                  return s.isEmpty || s.contains(c.gradeLevel);
                }).toSet();
              }),
              selectedColor: navy,
            ),
          ],
          if (showClass && _visibleClasses.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilterChipGrid<String>(
              title: _tingkat.isEmpty ? 'Kelas' : 'Kelas (tingkat terpilih)',
              multiSelect: true,
              options: [
                for (final c in _visibleClasses)
                  FilterOption(value: c.id, label: c.name),
              ],
              selectedValues: _classIds,
              onMultiSelected: (s) => setState(() => _classIds = s),
              selectedColor: navy,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
