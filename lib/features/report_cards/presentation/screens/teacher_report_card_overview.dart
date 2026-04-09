import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';

/// Flat overview for Raport — shows homeroom classes with completion stats.
/// Tap a class → opens the student list as a dialog.
class ReportCardOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const ReportCardOverviewPage({super.key, required this.teacher});
  @override
  ConsumerState<ReportCardOverviewPage> createState() => _ReportCardOverviewPageState();
}

class _ReportCardOverviewPageState extends ConsumerState<ReportCardOverviewPage> {
  List<dynamic> _classData = [];
  bool _isLoading = true;

  String get _teacherId => (widget.teacher['teacher_id'] ?? widget.teacher['id'])?.toString() ?? '';
  Color get _p => ColorUtils.getRoleColor('guru');

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final data = await ApiReportCardService.getTeacherRaportSummary(teacherId: _teacherId, academicYearId: ayId);
      if (mounted) setState(() { _classData = data; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e)); }
    }
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

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(children: [_buildHeader(lp), Expanded(child: _buildContent(lp))]),
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
            Text(lp.getTranslatedText({'en': 'Report Cards', 'id': 'Raport'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(lp.getTranslatedText({'en': 'Manage student report cards', 'id': 'Kelola raport siswa'}), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildContent(LanguageProvider lp) {
    if (_isLoading) return const SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    if (_classData.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: lp.getTranslatedText({'en': 'No Homeroom Class', 'id': 'Bukan Wali Kelas'}),
        subtitle: lp.getTranslatedText({'en': 'Report cards are managed by homeroom teachers', 'id': 'Raport dikelola oleh wali kelas'}),
      );
    }
    return RefreshIndicator(onRefresh: _loadData, color: _p, child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _classData.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 300 + (i * 60)),
        tween: Tween(begin: 0.0, end: 1.0), curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
        child: _classCard(_classData[i]),
      ),
    ));
  }

  Widget _classCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final studentCount = g['student_count'] ?? 0;
    final totalRaports = g['total_raports'] ?? 0;
    final draftCount = g['draft_count'] ?? 0;
    final finalCount = g['final_count'] ?? 0;
    final publishedCount = g['published_count'] ?? 0;
    final completionPct = g['completion_pct'] ?? 0;
    final pctColor = completionPct >= 80 ? ColorUtils.success600 : (completionPct >= 40 ? ColorUtils.warning600 : ColorUtils.slate300);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: () => _openClassRaport(g),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: completionPct / 100, strokeWidth: 4, backgroundColor: ColorUtils.slate100, color: pctColor)),
                Text('${completionPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pctColor)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kelas: $cn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
                const SizedBox(height: 2),
                Text('$totalRaports/$studentCount siswa', style: TextStyle(fontSize: 12, color: _p, fontWeight: FontWeight.w600)),
              ])),
              Icon(Icons.chevron_right_rounded, size: 20, color: ColorUtils.slate300),
            ]),
            const SizedBox(height: 10),
            // Status chips
            Row(children: [
              if (draftCount > 0) _statusChip('Draft $draftCount', ColorUtils.warning600),
              if (finalCount > 0) _statusChip('Final $finalCount', ColorUtils.info600),
              if (publishedCount > 0) _statusChip('Terbit $publishedCount', ColorUtils.success600),
              if (totalRaports == 0) _statusChip('Belum ada raport', ColorUtils.slate400),
            ]),
          ]),
        ),
      )),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
