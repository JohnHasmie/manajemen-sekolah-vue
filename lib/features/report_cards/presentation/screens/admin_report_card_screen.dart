/// Admin report card (raport) per-class detail — v3 redesign.
///
/// Drilled into from `AdminRaportHubScreen` via the per-kelas chip on
/// each `TingkatGroupCard`. Visual language now mirrors the hub:
///   • Navy gradient hero with kicker + title + period pill
///   • Stats strip showing siswa count + reviewed/terbit pct
///   • White rounded body with v3 student rows (status-coloured edge,
///     status pill, PDF action)
///   • Pinned action footer: Export Excel + Kirim ke Wali
///
/// Existing data/action mixins are reused unchanged — only the render
/// surface was rebuilt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_actions_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_utils_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/admin_report_card_body.dart';

class AdminReportCardScreen extends ConsumerStatefulWidget {
  /// When non-null, auto-selects this class on load (used when
  /// drilling in from the Raport hub's per-kelas chip).
  final String? initialClassId;

  const AdminReportCardScreen({super.key, this.initialClassId});

  @override
  ConsumerState createState() => _AdminReportCardScreenState();
}

class _AdminReportCardScreenState extends ConsumerState<AdminReportCardScreen>
    with
        AdminReportCardDataMixin,
        AdminReportCardActionsMixin,
        AdminReportCardUtilsMixin,
        AdminAcademicYearReloadMixin<AdminReportCardScreen> {
  /// Reload the class list (and clear the in-progress student
  /// selection) when admin flips the dashboard AY picker. Classes
  /// are AY-scoped, so the old selection is meaningless under a new
  /// year — wiping `_selectedClass` + `_students` prevents flashes
  /// of stale data while the fresh list loads.
  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    setState(() {
      _selectedClass = null;
      _students = [];
      _isLoading = true;
    });
    loadInitialData();
  }

  late LanguageProvider _languageProvider;

  bool _isLoading = true;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  bool _isPublishing = false;
  String _errorMessage = '';

  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  List<dynamic> _students = [];

  final GlobalKey _selectClassKey = GlobalKey();
  final GlobalKey _studentListKey = GlobalKey();
  final GlobalKey _exportBtnKey = GlobalKey();
  final GlobalKey _publishBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _languageProvider = ref.read(languageRiverpod);
    _loadAndAutoSelect();
  }

  Future<void> _loadAndAutoSelect() async {
    await loadInitialData();
    if (!mounted) return;
    final targetId = widget.initialClassId;
    if (targetId != null && _classes.isNotEmpty) {
      final match = _classes.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c?['id']?.toString() == targetId,
        orElse: () => null,
      );
      if (match != null) {
        setState(() {
          _selectedClass = match;
          _students = [];
        });
        loadStudents();
      }
    }
  }

  // Stats derived from the loaded student list — drives the hero strip.
  int get _terbitCount {
    var c = 0;
    for (final s in _students) {
      // Backend rename: `raport_status` → `report_card_status`.
      final m = s as Map?;
      final st = (m?['report_card_status'] ?? m?['raport_status'])?.toString();
      if (st == 'published') c++;
    }
    return c;
  }

  int get _finalCount {
    var c = 0;
    for (final s in _students) {
      // Backend rename: `raport_status` → `report_card_status`.
      final m = s as Map?;
      final st = (m?['report_card_status'] ?? m?['raport_status'])?.toString();
      if (st == 'final') c++;
    }
    return c;
  }

  int get _reviewedPct => _students.isEmpty
      ? 0
      : (((_terbitCount + _finalCount) / _students.length) * 100).round();

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHero(navy),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty && _classes.isEmpty) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHero(navy),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColorUtils.slate200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 36,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Gagal memuat data raport',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ColorUtils.slate500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: navy),
                          onPressed: loadInitialData,
                          child: Text(AppLocalizations.tryAgain.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHero(navy),
          Expanded(
            child: AdminReportCardBody(
              classes: _classes,
              selectedClass: _selectedClass,
              students: _students,
              isLoadingStudents: _isLoadingStudents,
              primaryColor: navy,
              selectClassKey: _selectClassKey,
              studentListKey: _studentListKey,
              onClassChanged: (value) {
                setState(() {
                  _selectedClass = value;
                  _students = [];
                });
                if (value != null) loadStudents();
              },
              onViewDetail: viewReportCardDetail,
              onDownloadPdf: downloadStudentPdf,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(navy),
    );
  }

  /// Navy gradient hero matching the Mockup #08 hub. Three states:
  ///   • Class selected — kicker / "Kelas 7A" / period pill / stats strip
  ///   • No class yet   — kicker / "Pilih Kelas" / period pill / count
  Widget _buildHero(Color navy) {
    final cls = _selectedClass;
    final hasClass = cls != null;
    final clsName = (cls?['name'] ?? '').toString();
    final tingkat = cls?['grade_level'] ?? cls?['tingkat'];

    return Container(
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient('admin'),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top action row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => AppNavigator.pop(context),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'refresh') forceRefresh();
                    },
                    color: Colors.white,
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 18,
                              color: ColorUtils.info600,
                            ),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.updateData.tr),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Title block
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akademik · Penilaian',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasClass
                        ? 'Raport · ${clsName.isEmpty ? '-' : clsName}'
                        : 'Raport per kelas',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Period + tingkat pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _HeroPill(label: 'Periode aktif · Ganjil'),
                      if (hasClass && tingkat != null)
                        _HeroPill(label: 'Tingkat $tingkat'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Stats strip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: hasClass ? _buildStatsStrip() : _buildClassCountHint(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            kicker: 'TOTAL SISWA',
            value: _isLoadingStudents ? '—' : _students.length.toString(),
            tone: _StatTone.translucent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            kicker: 'TERBIT',
            value: _isLoadingStudents ? '—' : _terbitCount.toString(),
            tone: _StatTone.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            kicker: 'DIPERIKSA',
            value: _isLoadingStudents ? '—' : '$_reviewedPct%',
            tone: _StatTone.translucent,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCountHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.class_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '${_classes.length} kelas tersedia · pilih satu untuk lanjut',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(Color navy) {
    if (_selectedClass == null || _isLoadingStudents || _students.isEmpty) {
      return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
        border: Border(top: BorderSide(color: ColorUtils.slate200, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _FooterButton(
                  key: _exportBtnKey,
                  icon: Icons.file_download_rounded,
                  label: 'Export Excel',
                  loading: _isExporting,
                  background: Colors.white,
                  foreground: navy,
                  border: ColorUtils.slate200,
                  onTap: _isExporting ? null : exportToExcel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FooterButton(
                  key: _publishBtnKey,
                  icon: Icons.send_rounded,
                  label: 'Kirim ke Wali',
                  loading: _isPublishing,
                  background: navy,
                  foreground: Colors.white,
                  onTap: _isPublishing ? null : publishReportCards,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mixin property accessors
  @override
  List<dynamic> get classes => _classes;
  @override
  set classes(List<dynamic> value) => _classes = value;
  @override
  Map<String, dynamic>? get selectedClass => _selectedClass;
  @override
  set selectedClass(Map<String, dynamic>? value) => _selectedClass = value;
  @override
  List<dynamic> get students => _students;
  @override
  set students(List<dynamic> value) => _students = value;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;
  @override
  bool get isLoadingStudents => _isLoadingStudents;
  @override
  set isLoadingStudents(bool value) => _isLoadingStudents = value;
  @override
  String get errorMessage => _errorMessage;
  @override
  set errorMessage(String value) => _errorMessage = value;
  @override
  bool get isExporting => _isExporting;
  @override
  set isExporting(bool value) => _isExporting = value;
  @override
  bool get isPublishing => _isPublishing;
  @override
  set isPublishing(bool value) => _isPublishing = value;
  @override
  LanguageProvider get languageProvider => _languageProvider;
  @override
  GlobalKey get selectClassKey => _selectClassKey;
  @override
  GlobalKey get studentListKey => _studentListKey;
  @override
  GlobalKey get exportBtnKey => _exportBtnKey;
  @override
  GlobalKey get publishBtnKey => _publishBtnKey;
}

// =====================================================================
// Hero subwidgets
// =====================================================================

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

enum _StatTone { translucent, success }

class _StatTile extends StatelessWidget {
  final String kicker;
  final String value;
  final _StatTone tone;

  const _StatTile({
    required this.kicker,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _StatTone.translucent => Colors.white.withValues(alpha: 0.18),
      _StatTone.success => const Color(0xFF10B981).withValues(alpha: 0.32),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kicker,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  const _FooterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.loading,
    required this.background,
    required this.foreground,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(foreground),
                  ),
                )
              else
                Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
