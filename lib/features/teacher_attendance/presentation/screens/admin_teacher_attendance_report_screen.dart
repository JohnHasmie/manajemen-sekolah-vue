// admin_teacher_attendance_report_screen.dart — the ADMIN-facing report
// for "Presensi Guru" (teacher daily attendance). Mobile parity for the
// web admin report tab (web-vue AdminTeacherAttendanceView.vue → the
// "Laporan" tab; the web "Pengaturan"/settings tab is intentionally out
// of scope here — this is the missing REPORT founder Yahya flagged).
//
// What the admin sees, top to bottom:
//   1. The shared brand header ([BrandPageHeader], role: 'admin') — the
//      same Navy gradient + back button every admin deep screen wears.
//   2. A PERIOD filter card (start/end date + teacher-ID search) that
//      drives BOTH sections below, exactly like the web's shared periode.
//      Empty dates → the backend defaults to start-of-month → today.
//   3. REKAP per-teacher — an aggregated Present/Late/(…)/Total/%
//      table from `GET /teacher-attendance/admin/summary`. Status columns
//      are DYNAMIC, driven by the response's `meta.statuses`.
//   4. A collapsible DETAIL per-row list from `GET /teacher-attendance/
//      admin` — the school-scoped daily records (in/out times, location,
//      photo link) with its own single-date + status filters and
//      pagination. Lazy: only fetched on first expand (no wasted request
//      while collapsed), mirroring the web.
//
// THEME — admin tokens only (`ColorUtils.getRoleColor('admin')` ==
// brand navy, the slate neutral scale, and the semantic success/warning/
// error 600 weights). No off-palette hex literals, so a brand refresh in
// color_utils.dart repaints this screen too — same discipline as the
// teacher Presensi screen.
//
// ROLE-GATING — this screen is reached only from the admin dashboard's
// "Modul lain" strip (AdminDashboardBody is mounted by the dashboard
// only when effectiveRole == 'admin'), so navigation gates it to admins,
// consistent with the other admin attendance/report screens. The backend
// admin endpoints are themselves school-scoped + admin-authorized server
// side, so a non-admin who somehow reached the route would get a 403.
//
// Analogy for the Laravel/Vue reader: one "page component" that hydrates
// from two read APIs (the rekap leads; the detail list is lazy) — the
// server is the single source of truth for aggregation, date defaulting,
// and school-scoping, exactly like a Laravel controller + Resource.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/teacher_attendance/data/'
    'teacher_attendance_admin_service.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

/// Role key for every theme lookup on this screen — admin (brand navy).
const String _kRole = 'admin';

/// How many detail rows we pull per page (mirrors the web's `reportPerPage`).
const int _kPerPage = 25;

/// Standalone admin report screen for teacher daily attendance.
class AdminTeacherAttendanceReportScreen extends ConsumerStatefulWidget {
  const AdminTeacherAttendanceReportScreen({super.key});

  @override
  ConsumerState<AdminTeacherAttendanceReportScreen> createState() =>
      _AdminTeacherAttendanceReportScreenState();
}

class _AdminTeacherAttendanceReportScreenState
    extends ConsumerState<AdminTeacherAttendanceReportScreen> {
  final TeacherAttendanceAdminService _service =
      TeacherAttendanceAdminService();

  // ── Shared period filter (drives BOTH rekap + detail) ──────────────
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _teacherIdController = TextEditingController();

  // ── Detail-only filters (the rekap ignores these) ──────────────────
  DateTime? _detailDate;
  String _detailStatus = ''; // '' | 'present' | 'late'

  // ── Rekap (per-teacher summary) state ──────────────────────────────
  TeacherAttendanceAdminSummary? _summary;
  bool _summaryLoading = true;
  String? _summaryError;

  // ── Detail (per-row list) state ────────────────────────────────────
  bool _showDetail = false;
  bool _detailLoaded = false;
  TeacherAttendanceListResult? _detail;
  bool _detailLoading = false;
  String? _detailError;
  int _detailPage = 1;

  Color get _accent => ColorUtils.getRoleColor(_kRole);

  String? get _startStr =>
      _startDate == null ? null : DateFormat('yyyy-MM-dd').format(_startDate!);
  String? get _endStr =>
      _endDate == null ? null : DateFormat('yyyy-MM-dd').format(_endDate!);
  String? get _detailDateStr => _detailDate == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_detailDate!);

  bool get _hasActiveFilter =>
      _startDate != null ||
      _endDate != null ||
      _teacherIdController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _teacherIdController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────

  Future<void> _loadSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final summary = await _service.getSummary(
        startDate: _startStr,
        endDate: _endStr,
        teacherId: _teacherIdController.text,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = _messageFromError(e);
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final detail = await _service.getReport(
        date: _detailDateStr,
        startDate: _startStr,
        endDate: _endStr,
        teacherId: _teacherIdController.text,
        status: _detailStatus.isEmpty ? null : _detailStatus,
        perPage: _kPerPage,
        page: _detailPage,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailLoaded = true;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = _messageFromError(e);
        _detailLoading = false;
      });
    }
  }

  /// Apply the shared period/teacher filter: always refresh the rekap;
  /// refresh the detail list only when it's expanded (lazy).
  void _applyFilters() {
    _detailPage = 1;
    _loadSummary();
    if (_showDetail) _loadDetail();
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _teacherIdController.clear();
      _detailDate = null;
      _detailStatus = '';
      _detailPage = 1;
    });
    _loadSummary();
    if (_showDetail) _loadDetail();
  }

  void _toggleDetail() {
    setState(() => _showDetail = !_showDetail);
    if (_showDetail && !_detailLoaded) _loadDetail();
  }

  void _applyDetailFilters() {
    _detailPage = 1;
    _loadDetail();
  }

  void _goDetailPage(int n) {
    final meta = _detail?.meta;
    if (meta == null) return;
    if (n < 1 || n > meta.lastPage || n == meta.currentPage) return;
    setState(() => _detailPage = n);
    _loadDetail();
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(_startDate);
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(_endDate);
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickDetailDate() async {
    final picked = await _pickDate(_detailDate);
    if (picked != null) setState(() => _detailDate = picked);
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the language provider so every `.tr` resolution rebuilds when
    // the admin flips the app language.
    ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandPageHeader(
            role: _kRole,
            subtitle: kTarKicker.tr,
            title: kTarTitle.tr,
          ),
          Expanded(
            child: RefreshIndicator(
              color: _accent,
              onRefresh: () async {
                _loadSummary();
                if (_showDetail) _loadDetail();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  _buildPeriodFilter(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildRecapCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDetailToggle(),
                  if (_showDetail) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildDetailFilters(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDetailSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Period filter card ──────────────────────────────────────────────

  Widget _buildPeriodFilter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: kTarFrom.tr,
                  value: _startStr,
                  hint: kTarPickDate.tr,
                  accent: _accent,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DateField(
                  label: kTarTo.tr,
                  value: _endStr,
                  hint: kTarPickDate.tr,
                  accent: _accent,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FieldLabel(text: kTarTeacherIdLabel.tr),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _teacherIdController,
            decoration: InputDecoration(
              hintText: kTarTeacherIdHint.tr,
              prefixIcon: Icon(Icons.badge_outlined, size: 18, color: _accent),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ColorUtils.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ColorUtils.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _accent),
              ),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(kTarApply.tr),
                ),
              ),
              if (_hasActiveFilter) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(foregroundColor: _accent),
                  child: Text(kTarReset.tr),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kTarPeriodHint.tr,
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }

  // ── Rekap (per-teacher summary) card ────────────────────────────────

  Widget _buildRecapCard() {
    final summary = _summary;
    final rangeLabel = summary != null && summary.startDate.isNotEmpty
        ? '${_fmtDate(summary.startDate)} – ${_fmtDate(summary.endDate)}'
        : null;
    final teacherCount =
        summary?.totals.teacherCount ?? summary?.rows.length ?? 0;

    return Container(
      decoration: ColorUtils.corporateCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kTarRecapTitle.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (rangeLabel != null) rangeLabel,
                          '$teacherCount ${kTarTeacherCount.tr}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: ColorUtils.slate100),
          _buildRecapBody(),
        ],
      ),
    );
  }

  Widget _buildRecapBody() {
    if (_summaryLoading && _summary == null) {
      return _LoadingBlock(accent: _accent, label: kTarLoading.tr);
    }
    if (_summaryError != null) {
      return _ErrorBlock(
        message: _summaryError!,
        accent: _accent,
        onRetry: _loadSummary,
      );
    }
    final summary = _summary;
    if (summary == null || summary.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          title: kTarRecapEmptyTitle.tr,
          subtitle: kTarRecapEmptyDesc.tr,
          icon: Icons.insert_chart_outlined,
        ),
      );
    }
    return _RecapTable(summary: summary, accent: _accent);
  }

  // ── Detail toggle + section ─────────────────────────────────────────

  Widget _buildDetailToggle() {
    return Container(
      decoration: ColorUtils.corporateCard(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleDetail,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.list_alt_rounded, size: 18, color: _accent),
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kTarDetailTitle.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ColorUtils.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kTarDetailSubtitle.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _showDetail
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailFilters() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _DateField(
                  label: kTarSingleDate.tr,
                  value: _detailDateStr,
                  hint: kTarPickDate.tr,
                  accent: _accent,
                  onTap: _pickDetailDate,
                  onClear: _detailDate == null
                      ? null
                      : () => setState(() => _detailDate = null),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(text: kTarStatusFilter.tr),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md - 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _detailStatus,
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Text(kTarStatusAll.tr),
                            ),
                            DropdownMenuItem(
                              value: 'present',
                              child: Text(kTarPillPresent.tr),
                            ),
                            DropdownMenuItem(
                              value: 'late',
                              child: Text(kTarPillLate.tr),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _detailStatus = v ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyDetailFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(kTarApply.tr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection() {
    if (_detailLoading && _detail == null) {
      return Container(
        decoration: ColorUtils.corporateCard(),
        child: _LoadingBlock(accent: _accent, label: kTarLoading.tr),
      );
    }
    if (_detailError != null) {
      return Container(
        decoration: ColorUtils.corporateCard(),
        child: _ErrorBlock(
          message: _detailError!,
          accent: _accent,
          onRetry: _loadDetail,
        ),
      );
    }
    final detail = _detail;
    if (detail == null || detail.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: ColorUtils.corporateCard(),
        child: EmptyState(
          title: kTarDetailEmptyTitle.tr,
          subtitle: kTarDetailEmptyDesc.tr,
          icon: Icons.event_busy_outlined,
        ),
      );
    }

    final presentCount =
        detail.items.where((r) => r.status == 'present').length;
    final lateCount = detail.items.where((r) => r.status == 'late').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary chips for the current page.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _CountChip(
              label: '${detail.meta.total} ${kTarRecords.tr}',
              bg: ColorUtils.slate100,
              fg: ColorUtils.slate600,
            ),
            _CountChip(
              label: '$presentCount ${kTarOnTimeThisPage.tr}',
              bg: ColorUtils.success600.withValues(alpha: 0.12),
              fg: ColorUtils.success700,
            ),
            _CountChip(
              label: '$lateCount ${kTarLateThisPage.tr}',
              bg: ColorUtils.warning600.withValues(alpha: 0.12),
              fg: ColorUtils.warning700,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...detail.items.map((r) => _DetailRowCard(record: r, accent: _accent)),
        if (detail.meta.lastPage > 1) ...[
          const SizedBox(height: AppSpacing.md),
          _Pagination(
            meta: detail.meta,
            accent: _accent,
            onPage: _goDetailPage,
            pageLabel: kTarPageOf.tr,
          ),
        ],
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Turns any thrown error into a clean, admin-readable message. dioClient
  /// wraps server errors into typed [ApiException]s whose `toString()` is
  /// the backend message — so a 403/422 lands here verbatim.
  String _messageFromError(Object e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).toString();
    }
    if (e is ApiException) return e.toString();
    if (e is DioException) {
      return e.message ?? kTarLoadError.tr;
    }
    return kTarLoadError.tr;
  }
}

/// Indonesian/English column header for a DYNAMIC rekap status key.
/// `present` + `late` are always present; further keys (sick / excused /
/// absent) may appear in `meta.statuses`. Falls back to a Title-Cased
/// version of an unknown key so a new backend status never renders blank.
/// Mirrors the web `teacherAttendanceStatusColumnLabel`.
String teacherAttendanceStatusColumnLabel(String status) {
  switch (status) {
    case 'present':
      return kTarStatusPresent.tr;
    case 'late':
      return kTarStatusLate.tr;
    case 'sick':
      return kTarStatusSick.tr;
    case 'excused':
      return kTarStatusExcused.tr;
    case 'absent':
      return kTarStatusAbsent.tr;
    default:
      if (status.isEmpty) return status;
      return status[0].toUpperCase() + status.substring(1);
  }
}

/// Formats a "YYYY-MM-DD" date into a short Indonesian-style label.
String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    final d = DateTime.parse(raw);
    return DateFormat('d MMM yyyy', 'id_ID').format(d);
  } catch (_) {
    return raw;
  }
}

/// Formats an ISO8601 timestamp into "HH:mm" local time, '-' when null.
String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  } catch (_) {
    return iso;
  }
}

// ── Field widgets ──────────────────────────────────────────────────────

/// A small uppercase field label, matching the web's 10px tracked caps.
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: ColorUtils.slate400,
      ),
    );
  }
}

/// A tappable date field that opens a date picker. Shows a placeholder
/// when no date is selected; an optional clear affordance.
class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md - 2,
              vertical: AppSpacing.md - 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 15, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    hasValue ? _fmtDate(value) : hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasValue
                          ? ColorUtils.slate800
                          : ColorUtils.slate400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasValue && onClear != null)
                  InkWell(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: ColorUtils.slate400,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rekap table ────────────────────────────────────────────────────────

/// The per-teacher rekap, rendered as a horizontally-scrollable table so
/// the dynamic status columns + Total + % always fit on a phone. Mirrors
/// the web `<table>` (header / rows / totals tfoot).
class _RecapTable extends StatelessWidget {
  final TeacherAttendanceAdminSummary summary;
  final Color accent;

  const _RecapTable({required this.summary, required this.accent});

  @override
  Widget build(BuildContext context) {
    final statuses = summary.statuses;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - (AppSpacing.lg * 2),
        ),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(ColorUtils.slate50),
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columnSpacing: 20,
          horizontalMargin: AppSpacing.lg,
          columns: [
            DataColumn(label: _HeadCell(teacherAttendanceHeadName())),
            for (final s in statuses)
              DataColumn(
                label: _HeadCell(teacherAttendanceStatusColumnLabel(s)),
                numeric: true,
              ),
            DataColumn(label: _HeadCell(kTarTotalRow.tr), numeric: true),
            DataColumn(label: _HeadCell(kTarPresentPct.tr), numeric: true),
          ],
          rows: [
            for (final row in summary.rows)
              DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.teacherName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        if (row.employeeNumber != null)
                          Text(
                            row.employeeNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final s in statuses)
                    DataCell(
                      Text(
                        '${row.countFor(s)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate700,
                        ),
                      ),
                    ),
                  DataCell(
                    Text(
                      '${row.total}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ),
                  DataCell(_PctBadge(pct: row.presentPct)),
                ],
              ),
            // Totals row.
            DataRow(
              color: WidgetStatePropertyAll(ColorUtils.slate50),
              cells: [
                DataCell(
                  Text(
                    kTarTotalRow.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
                for (final s in statuses)
                  DataCell(
                    Text(
                      '${summary.totals.countFor(s)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ),
                DataCell(
                  Text(
                    '${summary.totals.total}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_fmtPct(summary.totals.presentPct)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Name" header cell label — reuses the detail column label.
String teacherAttendanceHeadName() => kTarColTeacher.tr;

class _HeadCell extends StatelessWidget {
  final String text;
  const _HeadCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate500,
      ),
    );
  }
}

/// The %-attendance badge: emerald ≥90, amber ≥75, red below — exactly
/// the thresholds the web uses.
class _PctBadge extends StatelessWidget {
  final double pct;
  const _PctBadge({required this.pct});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pct >= 90
        ? (ColorUtils.success600.withValues(alpha: 0.12), ColorUtils.success700)
        : pct >= 75
        ? (ColorUtils.warning600.withValues(alpha: 0.12), ColorUtils.warning700)
        : (ColorUtils.error600.withValues(alpha: 0.12), ColorUtils.error700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_fmtPct(pct)}%',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Drops a trailing ".0" so 90.0 reads "90" but 87.5 stays "87.5".
String _fmtPct(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

// ── Detail row card ────────────────────────────────────────────────────

/// One daily attendance record, as a card (mobile-friendly vs the web's
/// table row). Shows the teacher, date, status pill, in/out times, and
/// the location verdict.
class _DetailRowCard extends StatelessWidget {
  final TeacherAttendanceRecord record;
  final Color accent;

  const _DetailRowCard({required this.record, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.teacherName ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ColorUtils.slate800,
                      ),
                    ),
                    if (record.teacherEmployeeNumber != null)
                      Text(
                        record.teacherEmployeeNumber!,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate400,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusPill(isLate: record.isLate),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _fmtDate(record.date),
                style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TimeStat(
                  icon: Icons.login_rounded,
                  label: kTarColIn.tr,
                  value: _fmtTime(record.checkInAt),
                ),
              ),
              Expanded(
                child: _TimeStat(
                  icon: Icons.logout_rounded,
                  label: kTarColOut.tr,
                  value: _fmtTime(record.checkOutAt),
                ),
              ),
              Expanded(child: _LocationStat(record: record)),
            ],
          ),
        ],
      ),
    );
  }
}

/// On-time / late status pill (per-row detail) — mirrors the web pill.
class _StatusPill extends StatelessWidget {
  final bool isLate;
  const _StatusPill({required this.isLate});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = isLate
        ? (
            ColorUtils.warning600.withValues(alpha: 0.12),
            ColorUtils.warning700,
            kTarPillLate.tr,
          )
        : (
            ColorUtils.success600.withValues(alpha: 0.12),
            ColorUtils.success700,
            kTarPillPresent.tr,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// A compact in/out time stat — icon + label on top, time below.
class _TimeStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: ColorUtils.slate400),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
      ],
    );
  }
}

/// Location verdict stat: distance in metres, or a red "outside area"
/// flag — matching the web's location column logic.
class _LocationStat extends StatelessWidget {
  final TeacherAttendanceRecord record;
  const _LocationStat({required this.record});

  @override
  Widget build(BuildContext context) {
    late final String value;
    late final Color color;
    if (record.checkInOutsideGeofence) {
      value = kTarOutsideArea.tr;
      color = ColorUtils.error600;
    } else if (record.checkInDistanceM != null) {
      value = '${record.checkInDistanceM} m';
      color = ColorUtils.slate600;
    } else {
      value = '-';
      color = ColorUtils.slate400;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 12,
              color: ColorUtils.slate400,
            ),
            const SizedBox(width: 3),
            Text(
              kTarColLocation.tr,
              style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Small shared widgets ───────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _CountChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Prev / "Page n / m" / Next pager — mirrors the web pagination.
class _Pagination extends StatelessWidget {
  final TeacherAttendancePageMeta meta;
  final Color accent;
  final void Function(int) onPage;
  final String pageLabel;

  const _Pagination({
    required this.meta,
    required this.accent,
    required this.onPage,
    required this.pageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = meta.currentPage > 1;
    final canNext = meta.currentPage < meta.lastPage;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canPrev ? () => onPage(meta.currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: accent,
        ),
        Text(
          '$pageLabel ${meta.currentPage} / ${meta.lastPage}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
          ),
        ),
        IconButton(
          onPressed: canNext ? () => onPage(meta.currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: accent,
        ),
      ],
    );
  }
}

/// A centered loading block with a tinted spinner + caption.
class _LoadingBlock extends StatelessWidget {
  final Color accent;
  final String label;

  const _LoadingBlock({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// A centered error block with an icon, the message, and a retry button.
class _ErrorBlock extends StatelessWidget {
  final String message;
  final Color accent;
  final VoidCallback onRetry;

  const _ErrorBlock({
    required this.message,
    required this.accent,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: ColorUtils.slate400),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(kTarRetry.tr),
            ),
          ],
        ),
      ),
    );
  }
}
