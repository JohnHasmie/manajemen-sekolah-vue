import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

class GradePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const GradePage({super.key, required this.teacher});
  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends ConsumerState<GradePage> {
  List<dynamic> _groupedData = [];
  bool _isLoading = true;
  bool _isHomeroomView = false;
  bool _isTableView = false;
  final _searchController = TextEditingController();

  // Filters
  String? _filterClassId;
  String? _filterClassName;
  String? _filterSubjectId;
  String? _filterSubjectName;

  String get _teacherId => (widget.teacher['teacher_id'] ?? widget.teacher['id'])?.toString() ?? '';
  Color get _p => ColorUtils.getRoleColor('guru');

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final data = await GradeService.getTeacherGradeSummary(
        teacherId: _teacherId,
        academicYearId: ayId,
        view: _isHomeroomView ? 'wali_kelas' : 'mengajar',
        classId: _filterClassId,
        subjectId: _filterSubjectId,
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

  int get _activeFilterCount => (_filterClassId != null ? 1 : 0) + (_filterSubjectId != null ? 1 : 0);

  // Collect unique classes and subjects for filter dialog
  List<Map<String, String>> get _availableClasses {
    final seen = <String>{};
    return _groupedData.where((g) {
      final id = g['class_id']?.toString() ?? '';
      if (seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).map((g) => {'id': g['class_id']?.toString() ?? '', 'name': g['class_name']?.toString() ?? '-'}).toList();
  }

  List<Map<String, String>> get _availableSubjects {
    final seen = <String>{};
    final list = <Map<String, String>>[];
    for (final g in _groupedData) {
      for (final s in (g['subjects'] as List? ?? [])) {
        final id = s['id']?.toString() ?? '';
        if (!seen.contains(id)) { seen.add(id); list.add({'id': id, 'name': s['name']?.toString() ?? '-'}); }
      }
    }
    return list;
  }

  void _openGradeBook(dynamic classData, dynamic subject) {
    AppNavigator.push(context, GradeBookPage(
      teacher: widget.teacher,
      subject: {'id': subject['id'], 'nama': subject['name'], 'name': subject['name'], 'kode': subject['code'], 'code': subject['code']},
      classData: {'id': classData['class_id'], 'nama': classData['class_name'], 'name': classData['class_name'], 'grade_level': classData['grade_level']},
    ));
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
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
      body: Column(children: [_buildHeader(lp), if (_activeFilterCount > 0) _buildFilterChips(), Expanded(child: _buildContent(lp))]),
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
            Text(lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(lp.getTranslatedText({'en': 'Manage student grades', 'id': 'Kelola nilai siswa'}), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          ])),
          GestureDetector(
            onTap: () => setState(() => _isTableView = !_isTableView),
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_isTableView ? Icons.view_agenda_rounded : Icons.table_chart_rounded, color: Colors.white, size: 18)),
          ),
        ]),
        const SizedBox(height: 14),
        // Row 2: role toggle
        _buildRoleToggle(lp),
        const SizedBox(height: 14),
        // Row 3: search + filter button
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
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                isCollapsed: true,
              ),
            ),
          )),
          const SizedBox(width: 10),
          // Filter button
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

  Widget _buildRoleToggle(LanguageProvider lp) {
    return Container(
      height: 42, padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Stack(alignment: Alignment.center, children: [
        AnimatedAlign(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
          alignment: _isHomeroomView ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: 0.5, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))])))),
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _tab(Icons.person_outline_rounded, lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}), !_isHomeroomView, () { if (_isHomeroomView) { setState(() { _isHomeroomView = false; _filterClassId = null; _filterClassName = null; _filterSubjectId = null; _filterSubjectName = null; }); _loadData(); } }),
          _tab(Icons.class_outlined, lp.getTranslatedText({'en': 'Homeroom', 'id': 'Wali Kelas'}), _isHomeroomView, () { if (!_isHomeroomView) { setState(() { _isHomeroomView = true; _filterClassId = null; _filterClassName = null; _filterSubjectId = null; _filterSubjectName = null; }); _loadData(); } }),
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

  // ── Filter chips bar ──

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    String? tempClassId = _filterClassId;
    String? tempClassName = _filterClassName;
    String? tempSubjectId = _filterSubjectId;
    String? tempSubjectName = _filterSubjectName;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSS) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Text('Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
              const Spacer(),
              GestureDetector(onTap: () { setSS(() { tempClassId = null; tempClassName = null; tempSubjectId = null; tempSubjectName = null; }); },
                child: Text('Reset', style: TextStyle(fontSize: 13, color: ColorUtils.error600, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
            // Class filter
            Align(alignment: Alignment.centerLeft, child: Text('Kelas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _availableClasses.map((c) {
              final selected = c['id'] == tempClassId;
              return ChoiceChip(
                label: Text(c['name']!), selected: selected, showCheckmark: false,
                labelStyle: TextStyle(fontSize: 12, color: selected ? _p : ColorUtils.slate600, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                selectedColor: _p.withValues(alpha: 0.12), side: BorderSide(color: selected ? _p.withValues(alpha: 0.3) : ColorUtils.slate200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => setSS(() { tempClassId = selected ? null : c['id']; tempClassName = selected ? null : c['name']; }),
              );
            }).toList()),
            const SizedBox(height: 16),
            // Subject filter
            Align(alignment: Alignment.centerLeft, child: Text('Mata Pelajaran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _availableSubjects.map((s) {
              final selected = s['id'] == tempSubjectId;
              return ChoiceChip(
                label: Text(s['name']!), selected: selected, showCheckmark: false,
                labelStyle: TextStyle(fontSize: 12, color: selected ? _p : ColorUtils.slate600, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                selectedColor: _p.withValues(alpha: 0.12), side: BorderSide(color: selected ? _p.withValues(alpha: 0.3) : ColorUtils.slate200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => setSS(() { tempSubjectId = selected ? null : s['id']; tempSubjectName = selected ? null : s['name']; }),
              );
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() { _filterClassId = tempClassId; _filterClassName = tempClassName; _filterSubjectId = tempSubjectId; _filterSubjectName = tempSubjectName; });
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _p, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Terapkan', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            )),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
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
        icon: _isHomeroomView ? Icons.class_outlined : Icons.grade_outlined,
        title: _isHomeroomView ? lp.getTranslatedText({'en': 'No Homeroom Class', 'id': 'Bukan Wali Kelas'}) : lp.getTranslatedText({'en': 'No Classes Found', 'id': 'Tidak Ada Kelas'}),
        subtitle: _isHomeroomView ? lp.getTranslatedText({'en': 'You are not assigned as homeroom teacher', 'id': 'Anda tidak ditugaskan sebagai wali kelas'}) : lp.getTranslatedText({'en': 'No teaching assignments found', 'id': 'Tidak ada jadwal mengajar ditemukan'}),
      );
    }
    return RefreshIndicator(onRefresh: _refresh, color: _p, child: _isTableView ? _buildTableView(data) : ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: data.length,
      itemBuilder: (_, i) => _classCard(data[i]),
    ));
  }

  Widget _classCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final subjects = (g['subjects'] as List?) ?? [];
    final studentCount = g['student_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate100)),
      child: Column(children: [
        // Class header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Text(cn, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
            const Spacer(),
            Text('$studentCount siswa', style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
          ]),
        ),
        Divider(height: 1, color: ColorUtils.slate100),
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
    final code = subject['code']?.toString();
    final rawAvg = subject['avg_score'];
    final avg = rawAvg is num ? rawAvg.toDouble() : null;
    final total = subject['total_grades'] ?? 0;
    final maxScore = subject['max_score'] is num ? (subject['max_score'] as num).toDouble() : null;
    final minScore = subject['min_score'] is num ? (subject['min_score'] as num).toDouble() : null;
    final dist = _safeMap(subject['distribution']);
    final high = dist['high'] is num ? (dist['high'] as num).toInt() : 0;
    final mid = dist['mid'] is num ? (dist['mid'] as num).toInt() : 0;
    final low = dist['low'] is num ? (dist['low'] as num).toInt() : 0;
    final distTotal = high + mid + low;
    final assessments = (subject['assessments'] as List?) ?? [];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGradeBook(classData, subject),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: Subject name + average badge + chevron
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sn, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _p)),
                if (code != null && code.isNotEmpty)
                  Text(code, style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
              ])),
              if (avg != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _scoreColor(avg).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _scoreColor(avg))),
                    Text('Rata-rata', style: TextStyle(fontSize: 7, color: _scoreColor(avg).withValues(alpha: 0.7))),
                  ]),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16, color: ColorUtils.slate300),
            ]),

            if (total > 0) ...[
              const SizedBox(height: 6),
              // Row 2: Per-assessment averages as chips
              Wrap(spacing: 6, runSpacing: 4, children: [
                ...assessments.map((a) {
                  final label = a['label']?.toString() ?? '';
                  final aAvg = a['avg'] is num ? (a['avg'] as num).toDouble() : null;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$label ', style: TextStyle(fontSize: 9, color: ColorUtils.slate400)),
                      Text(aAvg != null ? aAvg.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: aAvg != null ? _scoreColor(aAvg) : ColorUtils.slate300)),
                    ]),
                  );
                }),
                if (minScore != null && maxScore != null)
                  Text('${minScore.toStringAsFixed(0)}–${maxScore.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: ColorUtils.slate400)),
              ]),

              // Row 3: Distribution bar
              if (distTotal > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(height: 4, child: Row(children: [
                    if (high > 0) Expanded(flex: high, child: Container(color: ColorUtils.success600)),
                    if (mid > 0) Expanded(flex: mid, child: Container(color: ColorUtils.warning600)),
                    if (low > 0) Expanded(flex: low, child: Container(color: ColorUtils.error600)),
                  ])),
                ),
              ],
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Belum ada nilai', style: TextStyle(fontSize: 11, color: ColorUtils.slate300, fontStyle: FontStyle.italic)),
              ),
          ]),
        ),
      ),
    );
  }


  // ── Table view — per-assessment averages ──

  Widget _buildTableView(List<dynamic> data) {
    final rows = <Map<String, dynamic>>[];
    for (final g in data) {
      for (final s in (g['subjects'] as List? ?? [])) {
        rows.add({...Map<String, dynamic>.from(g as Map), 'subject': s});
      }
    }

    // Collect all unique assessment labels in order
    final allLabels = <String>[];
    for (final r in rows) {
      for (final a in ((r['subject']?['assessments'] as List?) ?? [])) {
        final l = a['label']?.toString() ?? '';
        if (l.isNotEmpty && !allLabels.contains(l)) allLabels.add(l);
      }
    }

    const cellW = 50.0;
    final scrollWidth = 56.0 + 80.0 + (allLabels.length * cellW) + 48.0 + 24.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollWidth < MediaQuery.of(context).size.width - 24 ? MediaQuery.of(context).size.width - 24 : scrollWidth,
            child: Column(children: [
              // Header
              Container(
                color: _p,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(width: 56, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('Kelas', style: _hStyle))),
                  SizedBox(width: 80, child: Text('Mapel', style: _hStyle)),
                  ...allLabels.map((l) => SizedBox(width: cellW, child: Text(l, style: _hStyle, textAlign: TextAlign.center))),
                  SizedBox(width: 48, child: Text('Avg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center)),
                  const SizedBox(width: 24),
                ]),
              ),
              // Rows
              ...rows.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final sub = r['subject'];
                final aList = (sub?['assessments'] as List?) ?? [];
                final avgMap = <String, double>{};
                for (final a in aList) {
                  final l = a['label']?.toString() ?? '';
                  if (l.isNotEmpty && a['avg'] is num) avgMap[l] = (a['avg'] as num).toDouble();
                }
                final rawAvg = sub?['avg_score'];
                final avg = rawAvg is num ? rawAvg.toDouble() : null;

                return Material(
                  color: i.isEven ? Colors.white : ColorUtils.slate50,
                  child: InkWell(
                    onTap: () => _openGradeBook(r, sub),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ColorUtils.slate100))),
                      child: Row(children: [
                        SizedBox(width: 56, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r['class_name']?.toString() ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ColorUtils.slate900)))),
                        SizedBox(width: 80, child: Text(sub?['name']?.toString() ?? '-', style: TextStyle(fontSize: 11, color: _p, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ...allLabels.map((l) {
                          final v = avgMap[l];
                          return SizedBox(width: cellW, child: Text(v != null ? v.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: v != null ? FontWeight.w700 : FontWeight.w400, color: v != null ? _scoreColor(v) : ColorUtils.slate300)));
                        }),
                        SizedBox(width: 48, child: avg != null
                            ? Text(avg.toStringAsFixed(0), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _scoreColor(avg)))
                            : Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ColorUtils.slate300))),
                        SizedBox(width: 24, child: Icon(Icons.chevron_right_rounded, size: 14, color: ColorUtils.slate300)),
                      ]),
                    ),
                  ),
                );
              }),
            ]),
          ),
        ),
      ),
    );
  }

  TextStyle get _hStyle => const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white);

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

}
