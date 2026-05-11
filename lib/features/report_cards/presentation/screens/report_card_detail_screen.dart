import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_grade_tab.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_extras_tab.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_info_tab.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_header.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_footer.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_populate_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_save_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_ui_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_nav_mixin.dart';

/// Report card detail form for a single student.
///
/// A complex multi-tab form with academic grades,
/// extracurriculars, character assessment, and
/// attendance/promotion info.
class ReportCardDetailScreen extends ConsumerStatefulWidget {
  final String studentClassId;
  final String studentName;
  final String className;

  const ReportCardDetailScreen({
    super.key,
    required this.studentClassId,
    required this.studentName,
    required this.className,
  });

  @override
  ConsumerState createState() => _ReportCardDetailScreenState();
}

/// State for [ReportCardDetailScreen].
///
/// Uses mixin-based decomposition for:
/// - Data loading and caching
/// - Form population
/// - Save operations
/// - Tour/tutorial features
/// - UI building
/// - Navigation
class _ReportCardDetailScreenState extends ConsumerState<ReportCardDetailScreen>
    with
        SingleTickerProviderStateMixin,
        ReportCardDataMixin,
        ReportCardPopulateMixin,
        ReportCardSaveMixin,
        ReportCardUIMixin,
        ReportCardNavMixin {
  late TabController tabController;

  // State: Loading and errors
  @override
  bool isLoading = true;
  @override
  bool isSaving = false;
  @override
  String errorMessage = '';
  @override
  bool hasUnsavedChanges = false;

  // State: Data containers
  @override
  Map<String, dynamic>? existingRaport;

  // State: Form controllers - Sikap
  @override
  late TextEditingController spiritualDescCtrl;
  @override
  late TextEditingController socialDescCtrl;
  @override
  String spiritualPredicate = 'Baik';
  @override
  String socialPredicate = 'Baik';

  // State: Form controllers - Info
  @override
  late TextEditingController sickCtrl;
  @override
  late TextEditingController permitCtrl;
  @override
  late TextEditingController absentCtrl;
  @override
  late TextEditingController notesCtrl;
  @override
  String promotionDecision = 'Naik Kelas';

  // State: Lists
  @override
  List<Map<String, dynamic>> subjects = [];
  @override
  List<Map<String, dynamic>> extras = [];
  @override
  List<Map<String, dynamic>> achievements = [];

  // Constants
  @override
  final List<String> predicates = ['Sangat Baik', 'Baik', 'Cukup', 'Kurang'];
  final List<String> decisions = ['Naik Kelas', 'Tinggal di Kelas'];

  // Tour keys
  @override
  late GlobalKey tabKey;
  @override
  late GlobalKey saveDraftKey;
  @override
  late GlobalKey finalizeKey;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);

    spiritualDescCtrl = TextEditingController();
    socialDescCtrl = TextEditingController();
    sickCtrl = TextEditingController(text: '0');
    permitCtrl = TextEditingController(text: '0');
    absentCtrl = TextEditingController(text: '0');
    notesCtrl = TextEditingController();

    tabKey = GlobalKey();
    saveDraftKey = GlobalKey();
    finalizeKey = GlobalKey();

    spiritualDescCtrl.addListener(markUnsaved);
    socialDescCtrl.addListener(markUnsaved);
    sickCtrl.addListener(markUnsaved);
    permitCtrl.addListener(markUnsaved);
    absentCtrl.addListener(markUnsaved);
    notesCtrl.addListener(markUnsaved);

    loadData();
  }

  @override
  void dispose() {
    tabController.dispose();
    spiritualDescCtrl.dispose();
    socialDescCtrl.dispose();
    sickCtrl.dispose();
    permitCtrl.dispose();
    absentCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = existingRaport?['status']?.toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: onPopInvoked,
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            ReportCardHeader(
              studentName: widget.studentName,
              className: widget.className,
              status: status,
              existingRaport: existingRaport,
              onBack: handleBackButton,
            ),
            // Spacer absorbs the hero card's 24dp overlap into the
            // gradient header (see ReportCardHeader.Stack +
            // Transform.translate). Without this the tab bar would
            // overlap the hero.
            const SizedBox(height: 36),
            _buildTabBar(),
            _buildBody(),
          ],
        ),
        bottomNavigationBar: ReportCardFooter(
          isSaving: isSaving,
          onSaveDraft: () => saveReportCard(status: 'draft'),
          onFinalize: _showFinalizeDialog,
          saveDraftKey: saveDraftKey,
          finalizeKey: finalizeKey,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final cobalt = ColorUtils.brandCobalt;

    return Container(
      key: tabKey,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: cobalt,
        unselectedLabelColor: ColorUtils.slate500,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: const [
          Tab(text: 'Sikap'),
          Tab(text: 'Nilai'),
          Tab(text: 'Tambahan'),
          Tab(text: 'Info'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Expanded(
      child: isLoading
          ? const SkeletonListLoading()
          : errorMessage.isNotEmpty
          ? Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : TabBarView(
              controller: tabController,
              children: [
                buildSikapTab(),
                ReportCardGradeTab(
                  subjects: subjects,
                  onSubjectChanged: (i, f, v) =>
                      setState(() => subjects[i][f] = v),
                  onMarkUnsaved: markUnsaved,
                ),
                ReportCardExtrasTab(
                  extras: extras,
                  achievements: achievements,
                  onAddExtra: () => setState(
                    () => extras.add({
                      'name': '',
                      'score': '',
                      'description': '',
                    }),
                  ),
                  onAddAchievement: () => setState(
                    () => achievements.add({
                      'name': '',
                      'type': '',
                      'description': '',
                    }),
                  ),
                  onExtraChanged: (i, f, v) => setState(() => extras[i][f] = v),
                  onDeleteExtra: (i) => setState(() => extras.removeAt(i)),
                  onAchievementChanged: (i, f, v) =>
                      setState(() => achievements[i][f] = v),
                  onDeleteAchievement: (i) =>
                      setState(() => achievements.removeAt(i)),
                  onMarkUnsaved: markUnsaved,
                ),
                ReportCardInfoTab(
                  sickCtrl: sickCtrl,
                  permitCtrl: permitCtrl,
                  absentCtrl: absentCtrl,
                  notesCtrl: notesCtrl,
                  promotionDecision: promotionDecision,
                  decisions: decisions,
                  onPromotionChanged: (v) {
                    setState(() => promotionDecision = v!);
                    markUnsaved();
                  },
                ),
              ],
            ),
    );
  }

  void _showFinalizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalisasi Rapor'),
        content: const Text(
          'Apakah Anda yakin ingin menyelesaikan rapor ini? Rapor yang telah difinalisasi tidak dapat diubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.cancel.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              saveReportCard(status: 'final');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.getRoleColor('guru'),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Finalisasi'),
          ),
        ],
      ),
    );
  }
}
