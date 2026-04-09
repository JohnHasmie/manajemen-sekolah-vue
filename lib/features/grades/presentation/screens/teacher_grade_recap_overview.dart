import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';

/// Flat overview for Rekap Nilai — matching Nilai/Mengajar pattern.
/// Tap a subject → opens GradeRecapPage as a dialog.
class GradeRecapOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const GradeRecapOverviewPage({super.key, required this.teacher});
  @override
  ConsumerState<GradeRecapOverviewPage> createState() => _GradeRecapOverviewPageState();
}

class _GradeRecapOverviewPageState extends ConsumerState<GradeRecapOverviewPage> {
  List<dynamic> _groupedData = [];
  bool _isLoading = true;
  bool _isHomeroomView = false;
  final _searchController = TextEditingController();
  String? _filterClassId, _filterClassName, _filterSubjectId, _filterSubjectName;

  String get _teacherId => (widget.teacher['teacher_id'] ?? widget.teacher['id'])?.toString() ?? '';
  Color get _p => ColorUtils.getRoleColor('guru');
  int get _activeFilterCount => (_filterClassId != null ? 1 : 0) + (_filterSubjectId != null ? 1 : 0);

  @override
  void initState() { super.initState(); _loadViewPref(); _loadData(); }
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('rekap_nilai_view_preference');
      if (c is Map && mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final data = await GradeService.getTeacherRecapSummary(
        teacherId: _teacherId, academicYearId: ayId,
        view: _isHomeroomView ? 'wali_kelas' : 'mengajar',
        classId: _filterClassId, subjectId: _filterSubjectId,
      );
      if (mounted) setState(() { _groupedData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e)); }
    }
  }

  Future<void> _refresh() async => _loadData();

  List<dynamic> get _filteredData {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return _groupedData;
    return _groupedData.where((g) {
      if ((g['class_name'] ?? '').toString().toLowerCase().contains(q)) return true;
      return ((g['subjects'] as List?) ?? []).any((s) => (s['name'] ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  List<Map<String, String>> get _availableClasses {
    final seen = <String>{};
    return _groupedData.where((g) { final id = g['class_id']?.toString() ?? ''; if (seen.contains(id)) return false; seen.add(id); return true; })
        .map((g) => {'id': g['class_id']?.toString() ?? '', 'name': g['class_name']?.toString() ?? '-'}).toList();
  }

  void _openRecapTable(dynamic classData, dynamic subject) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: GradeRecapPage(
            teacher: widget.teacher,
            initialClass: {'id': classData['class_id'], 'nama': classData['class_name'], 'name': classData['class_name']},
            initialSubject: {'id': subject['id'], 'nama': subject['name'], 'name': subject['name'], 'kode': subject['code']},
          ),
        ),
      ),
    ).then((_) => _loadData());
  }

  void _clearFilters() {
    setState(() { _filterClassId = null; _filterClassName = null; _filterSubjectId = null; _filterSubjectName = null; });
    _loadData();
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
        Row(children: [
          GestureDetector(onTap: () => AppNavigator.pop(context),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20))),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lp.getTranslatedText({'en': 'Grade Recap', 'id': 'Rekap Nilai'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(lp.getTranslatedText({'en': 'Manage grade recaps', 'id': 'Kelola rekap nilai siswa'}), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          ])),
        ]),
        const SizedBox(height: 14),
        // Role toggle
        Container(
          height: 42, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: Stack(alignment: Alignment.center, children: [
            AnimatedAlign(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: _isHomeroomView ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: 0.5, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))])))),
            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _tab(Icons.person_outline_rounded, lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}), !_isHomeroomView, () { if (_isHomeroomView) { setState(() { _isHomeroomView = false; _filterClassId = null; _filterClassName = null; _filterSubjectId = null; _filterSubjectName = null; }); _loadData(); } }),
              _tab(Icons.class_outlined, lp.getTranslatedText({'en': 'Homeroom', 'id': 'Wali Kelas'}), _isHomeroomView, () { if (!_isHomeroomView) { setState(() { _isHomeroomView = true; _filterClassId = null; _filterClassName = null; _filterSubjectId = null; _filterSubjectName = null; }); _loadData(); } }),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // Search + filter
        Row(children: [
          Expanded(child: Container(
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController, style: const TextStyle(color: Colors.black87, fontSize: 14),
              onChanged: (_) => setState(() {}),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: lp.getTranslatedText({'en': 'Search...', 'id': 'Cari...'}),
                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400, size: 20),
                suffixIcon: _searchController.text.isNotEmpty ? GestureDetector(onTap: () { _searchController.clear(); setState(() {}); }, child: Icon(Icons.close, color: ColorUtils.slate400, size: 18)) : null,
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14), isCollapsed: true,
              ),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showFilterDialog(lp),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20)),
              if (_activeFilterCount > 0) Positioned(right: -4, top: -4, child: Container(
                width: 18, height: 18, decoration: BoxDecoration(color: ColorUtils.error600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                child: Center(child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
              )),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _tab(IconData icon, String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap,
      child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: active ? _p : Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? _p : Colors.white.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]))));
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(Icons.filter_alt_outlined, size: 14, color: _p),
        const SizedBox(width: 6),
        if (_filterClassName != null) _chip(_filterClassName!, () { setState(() { _filterClassId = null; _filterClassName = null; }); _loadData(); }),
        if (_filterSubjectName != null) _chip(_filterSubjectName!, () { setState(() { _filterSubjectId = null; _filterSubjectName = null; }); _loadData(); }),
        const Spacer(),
        GestureDetector(onTap: _clearFilters, child: Text('Hapus', style: TextStyle(fontSize: 11, color: ColorUtils.error600, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _p.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: _p, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 12, color: _p)),
      ]),
    );
  }

  // ── Filter dialog (matching presensi pattern) ──

  Widget _filterSectionHeader(String title, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: _p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _p)),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
    ]));
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _p.withValues(alpha: 0.1) : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? _p : ColorUtils.slate200, width: isSelected ? 1.5 : 1),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? _p : ColorUtils.slate600)),
    ));
  }

  void _showFilterDialog(LanguageProvider lp) {
    String? tClassId = _filterClassId;
    String? tClassName = _filterClassName;
    String? tSubjectId = _filterSubjectId;
    String? tSubjectName = _filterSubjectName;
    List<dynamic> tSubjectList = [];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_p, _p.withValues(alpha: 0.85)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(lp.getTranslatedText({'en': 'Filter Recap', 'id': 'Filter Rekap'}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                  TextButton(onPressed: () => setSS(() { tClassId = null; tClassName = null; tSubjectId = null; tSubjectName = null; tSubjectList = []; }),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), backgroundColor: Colors.white.withValues(alpha: 0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ]),
            ),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _filterSectionHeader(lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}), Icons.class_outlined),
              Wrap(spacing: 8, runSpacing: 8, children: _availableClasses.map((c) {
                final selected = c['id'] == tClassId;
                return _filterChip(c['name']!, selected, () async {
                  setSS(() { tClassId = selected ? null : c['id']; tClassName = selected ? null : c['name']; tSubjectId = null; tSubjectName = null; tSubjectList = []; });
                  if (tClassId != null) { try { final r = await dioClient.get('/class/$tClassId/subjects'); setSS(() => tSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
                });
              }).toList()),
              const SizedBox(height: 24),
              if (tSubjectList.isNotEmpty || tClassId != null) ...[
                _filterSectionHeader(lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}), Icons.book_outlined),
                if (tSubjectList.isEmpty) Text(lp.getTranslatedText({'en': 'Loading...', 'id': 'Memuat...'}), style: TextStyle(color: ColorUtils.slate500, fontSize: 13))
                else Wrap(spacing: 8, runSpacing: 8, children: tSubjectList.map((s) {
                  final sid = s['id']?.toString();
                  final sname = (s['name'] ?? s['nama'] ?? '-').toString();
                  final selected = tSubjectId == sid;
                  return _filterChip(sname, selected, () => setSS(() { tSubjectId = selected ? null : sid; tSubjectName = selected ? null : sname; }));
                }).toList()),
              ],
            ]))),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))]),
              child: SafeArea(top: false, child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: ColorUtils.slate300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}), style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); setState(() { _filterClassId = tClassId; _filterClassName = tClassName; _filterSubjectId = tSubjectId; _filterSubjectName = tSubjectName; }); _loadData(); },
                  style: ElevatedButton.styleFrom(backgroundColor: _p, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(lp.getTranslatedText({'en': 'Apply', 'id': 'Terapkan'}), style: const TextStyle(fontWeight: FontWeight.w600)))),
              ])),
            ),
          ]),
        );
      }),
    );
  }

  // ── Content ──

  Widget _buildContent(LanguageProvider lp) {
    if (_isLoading) return const SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    final data = _filteredData;
    if (data.isEmpty) {
      return EmptyState(
        icon: _isHomeroomView ? Icons.class_outlined : Icons.assessment_outlined,
        title: _isHomeroomView ? lp.getTranslatedText({'en': 'No Homeroom Class', 'id': 'Bukan Wali Kelas'}) : lp.getTranslatedText({'en': 'No Classes Found', 'id': 'Tidak Ada Kelas'}),
        subtitle: lp.getTranslatedText({'en': 'No teaching assignments found', 'id': 'Tidak ada jadwal mengajar'}),
      );
    }
    return RefreshIndicator(onRefresh: _refresh, color: _p, child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: data.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 300 + (i * 60)),
        tween: Tween(begin: 0.0, end: 1.0), curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
        child: _classCard(data[i]),
      ),
    ));
  }

  Widget _classCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final subjects = (g['subjects'] as List?) ?? [];
    final studentCount = g['student_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text('Kelas: $cn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$studentCount siswa', style: TextStyle(fontSize: 10, color: _p, fontWeight: FontWeight.w600))),
          ]),
        ),
        Divider(height: 1, color: ColorUtils.slate200),
        ...subjects.asMap().entries.map((e) {
          final sub = e.value;
          final isLast = e.key == subjects.length - 1;
          return Column(children: [
            _subjectRow(g, sub),
            if (!isLast) Padding(padding: const EdgeInsets.only(left: 14), child: Divider(height: 1, color: ColorUtils.slate50)),
          ]);
        }),
      ]),
    );
  }

  Widget _subjectRow(dynamic classData, dynamic subject) {
    final sn = subject['name']?.toString() ?? '-';
    final recapCount = subject['recap_count'] ?? 0;
    final totalStudents = subject['total_students'] ?? 0;
    final completionPct = subject['completion_pct'] ?? 0;
    final avgScore = subject['avg_final_score'] is num ? (subject['avg_final_score'] as num).toDouble() : null;
    final babCount = subject['bab_count'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openRecapTable(classData, subject),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sn, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _p)),
              const SizedBox(height: 4),
              Row(children: [
                Text('$recapCount/$totalStudents siswa', style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
                if (babCount > 0) ...[
                  const SizedBox(width: 8),
                  Text('$babCount bab', style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
                ],
              ]),
              if (totalStudents > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
                  value: completionPct / 100, minHeight: 3,
                  backgroundColor: ColorUtils.slate100, color: completionPct >= 80 ? ColorUtils.success600 : (completionPct >= 40 ? ColorUtils.warning600 : ColorUtils.slate300),
                )),
              ],
            ])),
            if (avgScore != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _scoreColor(avgScore).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: Text(avgScore.toStringAsFixed(0), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _scoreColor(avgScore))),
              ),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: ColorUtils.slate300),
          ]),
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }
}
