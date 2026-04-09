import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';

class ReportCardOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const ReportCardOverviewPage({super.key, required this.teacher});
  @override
  ConsumerState<ReportCardOverviewPage> createState() => _ReportCardOverviewPageState();
}

class _ReportCardOverviewPageState extends ConsumerState<ReportCardOverviewPage> {
  List<dynamic> _classData = [];
  bool _isLoading = true;
  bool _isTableView = false;
  String? _filterStatus; // null=all, 'incomplete','draft','complete'
  final TextEditingController _searchController = TextEditingController();

  String get _teacherId => (widget.teacher['teacher_id'] ?? widget.teacher['id'])?.toString() ?? '';
  Color get _p => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final cached = await LocalCacheService.load('raport_overview_view');
    if (cached != null && mounted) {
      setState(() => _isTableView = cached['isTableView'] == true);
    }
  }

  void _saveViewPreference() {
    LocalCacheService.save('raport_overview_view', {'isTableView': _isTableView});
  }

  Future<void> _loadData() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final data = await ApiReportCardService.getTeacherRaportSummary(teacherId: _teacherId, academicYearId: ayId);
      if (mounted) setState(() { _classData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e)); }
    }
  }

  List<dynamic> get _filteredData {
    var list = _classData;
    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => (c['class_name']?.toString() ?? '').toLowerCase().contains(q)).toList();
    }
    if (_filterStatus != null) {
      list = list.where((c) {
        final total = c['total_raports'] ?? 0;
        final draft = c['draft_count'] ?? 0;
        final studentCount = c['student_count'] ?? 0;
        switch (_filterStatus) {
          case 'incomplete':
            return total < studentCount;
          case 'draft':
            return draft > 0;
          case 'complete':
            return total >= studentCount && draft == 0 && studentCount > 0;
          default:
            return true;
        }
      }).toList();
    }
    return list;
  }

  int get _activeFilterCount => (_filterStatus != null ? 1 : 0);

  void _clearFilters() {
    setState(() => _filterStatus = null);
  }

  void _openClassRaport(dynamic classItem) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: ReportCardScreen(
            teacher: widget.teacher.map((k, v) => MapEntry(k, v?.toString() ?? '')),
            initialClassId: classItem['class_id']?.toString(),
          ),
        ),
      ),
    ).then((_) => _loadData());
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(children: [
        _buildHeader(lp),
        if (_activeFilterCount > 0) _buildFilterChips(),
        Expanded(child: _buildContent(lp)),
      ]),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_p, _p.withValues(alpha: 0.85)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 1: back + title + view toggle
        Row(children: [
          GestureDetector(onTap: () => AppNavigator.pop(context),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20))),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lp.getTranslatedText({'en': 'Report Cards', 'id': 'Raport'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(lp.getTranslatedText({'en': 'Manage student report cards', 'id': 'Kelola raport siswa'}), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          ])),
          GestureDetector(
            onTap: () { setState(() => _isTableView = !_isTableView); _saveViewPreference(); },
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_isTableView ? Icons.view_agenda_rounded : Icons.table_chart_rounded, color: Colors.white, size: 18)),
          ),
        ]),
        const SizedBox(height: 14),
        // Row 2: search + filter
        Row(children: [
          Expanded(child: Container(
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController, style: const TextStyle(color: Colors.black87, fontSize: 14),
              onChanged: (_) => setState(() {}),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: lp.getTranslatedText({'en': 'Search class...', 'id': 'Cari kelas...'}),
                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(onTap: () { _searchController.clear(); setState(() {}); }, child: Icon(Icons.close, color: ColorUtils.slate400, size: 18))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                isCollapsed: true,
              ),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showFilterDialog(lp),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20)),
              if (_activeFilterCount > 0)
                Positioned(right: -4, top: -4, child: Container(
                  width: 18, height: 18, decoration: BoxDecoration(color: ColorUtils.error600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                )),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Filter chips bar ──

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(Icons.filter_alt_outlined, size: 14, color: _p),
        const SizedBox(width: 6),
        if (_filterStatus != null) _chip(_filterStatusLabel(), () => setState(() => _filterStatus = null)),
        const Spacer(),
        GestureDetector(onTap: _clearFilters, child: Text('Hapus', style: TextStyle(fontSize: 11, color: ColorUtils.error600, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _filterStatusLabel() {
    switch (_filterStatus) {
      case 'incomplete': return 'Belum Lengkap';
      case 'draft': return 'Ada Draft';
      case 'complete': return 'Selesai';
      default: return '';
    }
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _p.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: _p, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 12, color: _p)),
      ]),
    );
  }

  // ── Filter dialog ──

  void _showFilterDialog(LanguageProvider lp) {
    String? tempStatus = _filterStatus;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
            // Title
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(gradient: LinearGradient(colors: [_p, _p.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
              ]),
            ),
            // Content
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _filterSectionHeader('Status Raport', Icons.assignment_outlined),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _filterChip('Belum Lengkap', tempStatus == 'incomplete', () => setSS(() => tempStatus = tempStatus == 'incomplete' ? null : 'incomplete')),
                  _filterChip('Ada Draft', tempStatus == 'draft', () => setSS(() => tempStatus = tempStatus == 'draft' ? null : 'draft')),
                  _filterChip('Selesai', tempStatus == 'complete', () => setSS(() => tempStatus = tempStatus == 'complete' ? null : 'complete')),
                ]),
              ]),
            )),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))]),
              child: SafeArea(top: false, child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: ColorUtils.slate300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Batal', style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _filterStatus = tempStatus);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _p, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
              ])),
            ),
          ]),
        );
      }),
    );
  }

  Widget _filterSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: _p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _p)),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
      ]),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _p.withValues(alpha: 0.1) : ColorUtils.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _p : ColorUtils.slate200, width: isSelected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? _p : ColorUtils.slate600)),
      ),
    );
  }

  // ── Content ──

  Widget _buildContent(LanguageProvider lp) {
    if (_isLoading) return const SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    final data = _filteredData;
    if (_classData.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: lp.getTranslatedText({'en': 'No Homeroom Class', 'id': 'Bukan Wali Kelas'}),
        subtitle: lp.getTranslatedText({'en': 'Report cards are managed by homeroom teachers', 'id': 'Raport dikelola oleh wali kelas'}),
      );
    }
    if (data.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Tidak Ditemukan',
        subtitle: 'Tidak ada kelas yang cocok dengan filter',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _p,
      child: _isTableView ? _buildTableView(data) : _buildCardView(data),
    );
  }

  // ── Card view (default) ──

  Widget _buildCardView(List<dynamic> data) {
    // Compute overall stats
    int totalStudents = 0, totalFilled = 0, totalDraft = 0;
    for (final c in _classData) {
      totalStudents += (c['student_count'] as num?)?.toInt() ?? 0;
      totalFilled += (c['total_raports'] as num?)?.toInt() ?? 0;
      totalDraft += (c['draft_count'] as num?)?.toInt() ?? 0;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Overall summary
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.analytics_outlined, size: 16, color: _p),
              const SizedBox(width: 6),
              Text('Ringkasan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _SummaryItem(label: 'Total Siswa', value: '$totalStudents', color: ColorUtils.slate600),
              _SummaryItem(label: 'Terisi', value: '$totalFilled', color: ColorUtils.success600),
              _SummaryItem(label: 'Draft', value: '$totalDraft', color: ColorUtils.warning600),
              _SummaryItem(label: 'Belum', value: '${totalStudents - totalFilled}', color: ColorUtils.error600),
            ]),
            const SizedBox(height: 10),
            // Overall progress
            Row(children: [
              Text('Progress Keseluruhan', style: TextStyle(fontSize: 10, color: ColorUtils.slate400, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${totalStudents > 0 ? (totalFilled * 100 / totalStudents).round() : 0}%', style: TextStyle(fontSize: 10, color: _p, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: totalStudents > 0 ? totalFilled / totalStudents : 0,
                  backgroundColor: ColorUtils.slate100,
                  valueColor: AlwaysStoppedAnimation(_p),
                ),
              ),
            ),
          ]),
        ),

        // Class cards
        ...data.asMap().entries.map((e) => TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (e.key * 60)),
          tween: Tween(begin: 0.0, end: 1.0), curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
          child: _classCard(e.value),
        )),
      ],
    );
  }

  Widget _classCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final studentCount = g['student_count'] ?? 0;
    final totalRaports = g['total_raports'] ?? 0;
    final draftCount = g['draft_count'] ?? 0;
    final finalCount = g['final_count'] ?? 0;
    final publishedCount = g['published_count'] ?? 0;
    final completionPct = g['completion_pct'] ?? 0;
    final pctVal = (completionPct is num) ? completionPct.toDouble() : 0.0;
    final pctColor = pctVal >= 80 ? ColorUtils.success600 : (pctVal >= 40 ? ColorUtils.warning600 : ColorUtils.slate400);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: () => _openClassRaport(g),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate100),
          ),
          child: Row(children: [
            // Progress circle
            SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: pctVal / 100, strokeWidth: 3.5, backgroundColor: ColorUtils.slate100, color: pctColor)),
              Text('${pctVal.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pctColor)),
            ])),
            const SizedBox(width: 12),
            // Class info + status chips
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cn, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
              const SizedBox(height: 4),
              Row(children: [
                _miniChip('$totalRaports/$studentCount', _p),
                if (draftCount > 0) _miniChip('Draft $draftCount', ColorUtils.warning600),
                if (finalCount > 0) _miniChip('Final $finalCount', ColorUtils.info600),
                if (publishedCount > 0) _miniChip('Terbit $publishedCount', ColorUtils.success600),
                if (totalRaports == 0) _miniChip('Belum ada', ColorUtils.slate400),
              ]),
            ])),
            Icon(Icons.chevron_right_rounded, size: 20, color: ColorUtils.slate300),
          ]),
        ),
      )),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ── Table view ──

  Widget _buildTableView(List<dynamic> data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _p.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: _p.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            SizedBox(width: 120, child: Text('Kelas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _p))),
            Expanded(child: Text('Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _p))),
            SizedBox(width: 50, child: Text('Draft', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _p), textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text('Final', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _p), textAlign: TextAlign.center)),
          ]),
        ),
        // Table rows
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(children: data.asMap().entries.map((e) {
            final g = e.value;
            final isLast = e.key == data.length - 1;
            final cn = g['class_name']?.toString() ?? '-';
            final studentCount = g['student_count'] ?? 0;
            final totalRaports = g['total_raports'] ?? 0;
            final draftCount = g['draft_count'] ?? 0;
            final finalCount = g['final_count'] ?? 0;
            final publishedCount = g['published_count'] ?? 0;
            final pctVal = studentCount > 0 ? (totalRaports / studentCount * 100) : 0.0;
            final pctColor = pctVal >= 80 ? ColorUtils.success600 : (pctVal >= 40 ? ColorUtils.warning600 : ColorUtils.slate400);

            return Column(children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openClassRaport(g),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cn, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800)),
                        Text('$totalRaports/$studentCount siswa', style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
                      ])),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${pctVal.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pctColor)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(height: 4, child: LinearProgressIndicator(value: pctVal / 100, backgroundColor: ColorUtils.slate100, color: pctColor)),
                        ),
                      ])),
                      const SizedBox(width: 12),
                      SizedBox(width: 50, child: Center(child: Text(
                        '$draftCount',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: draftCount > 0 ? ColorUtils.warning600 : ColorUtils.slate300),
                      ))),
                      SizedBox(width: 50, child: Center(child: Text(
                        '${finalCount + publishedCount}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: (finalCount + publishedCount) > 0 ? ColorUtils.success600 : ColorUtils.slate300),
                      ))),
                    ]),
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: ColorUtils.slate100, indent: 14),
            ]);
          }).toList()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
    ]));
  }
}
