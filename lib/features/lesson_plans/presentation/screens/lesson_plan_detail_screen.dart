// RPP (lesson plan) detail view/edit bottom sheet with AI regeneration.
// Displays single RPP with all sections: competencies, objectives,
// activities, assessment.
//
// Presented as a draggable bottom sheet (flat-flow pattern) so detail + edit
// + per-field regeneration all happen without leaving the list screen, matching
// the teacher recommendation flow (#145). Call [RPPDetailPage.show] instead of
// pushing this widget as a route — the Scaffold shell was replaced with a
// sheet-shaped Container to match the other teacher sheets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_editor_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_detail_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_detail_preview.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_regen_sheet.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_regeneration_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_export_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_save_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/mixins/lesson_plan_ui_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/mixins/lesson_plan_helpers_mixin.dart';

class RPPDetailPage extends StatefulWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const RPPDetailPage({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  /// Opens the RPP detail view as a modal bottom sheet.
  ///
  /// Use this instead of pushing the widget onto the navigator. The sheet
  /// takes ~95% of screen height and adjusts for keyboard inset so the
  /// inline editor keeps its Quill toolbar visible while typing.
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlanData,
    bool isNew = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) =>
          RPPDetailPage(lessonPlanData: lessonPlanData, isNew: isNew),
    );
  }

  @override
  RPPDetailPageState createState() => RPPDetailPageState();
}

class RPPDetailPageState extends State<RPPDetailPage>
    with
        LessonPlanAiRegenerationMixin,
        LessonPlanExportMixin,
        LessonPlanSaveMixin,
        LessonPlanUiMixin,
        LessonPlanHelpersMixin {
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isLoadingLimits = false;
  bool _isDownloading = false;
  bool _contentWasEdited = false;
  String _editedContent = '';
  String? _regeneratingField;
  late Map<String, dynamic> _lessonPlanData;
  Map<String, dynamic> _regenLimits = {};

  static const List<Map<String, String>> _lessonPlanFields = [
    {
      'key': 'core_competence',
      'label': 'Kompetensi Inti (KI)',
      'altKey': 'kompetensi_inti',
    },
    {
      'key': 'basic_competence',
      'label': 'Kompetensi Dasar (KD)',
      'altKey': 'kompetensi_dasar',
    },
    {'key': 'indicator', 'label': 'Indikator', 'altKey': 'indikator'},
    {
      'key': 'learning_objective',
      'label': 'Tujuan Pembelajaran',
      'altKey': 'tujuan_pembelajaran',
    },
    {'key': 'main_material', 'label': 'Materi Pokok', 'altKey': ''},
    {'key': 'learning_method', 'label': 'Metode Pembelajaran', 'altKey': ''},
    {'key': 'media_tools', 'label': 'Media / Alat', 'altKey': ''},
    {'key': 'learning_source', 'label': 'Sumber Belajar', 'altKey': ''},
    {
      'key': 'learning_activities',
      'label': 'Kegiatan Pembelajaran',
      'altKey': 'kegiatan_inti',
    },
    {
      'key': 'assessment',
      'label': 'Penilaian (Asesmen)',
      'altKey': 'penilaian',
    },
  ];

  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
    _editedContent = formatLessonPlanContent();
    if (hasAiAdditionalData && lessonPlanId != null) {
      loadRegenLimits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
        decoration: BoxDecoration(
          color: ColorUtils.lightGray,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LessonPlanDetailHeader(
      title: 'Detail RPP',
      subtitle: getDisplayTitle(),
      isEditing: _isEditing,
      isSaving: _isSaving,
      primaryColor: primaryColor,
      onEditTap: _toggleEdit,
      onSaveTap: saveLessonPlan,
      onExportTap: _showExportMenu,
      onCopyTap: copyToClipboard,
    );
  }

  Widget _buildContent() {
    return _isEditing
        ? LessonPlanEditorView(
            content: _editedContent,
            primaryColor: primaryColor,
            onChanged: _updateContent,
            lessonPlanData: hasAiAdditionalData ? _lessonPlanData : null,
            fieldDefinitions: hasAiAdditionalData ? _lessonPlanFields : null,
            onFieldChanged: _updateField,
          )
        : LessonPlanDetailPreview(
            lessonPlanData: _lessonPlanData,
            editedContent: _editedContent,
            canRegen:
                hasAiAdditionalData &&
                lessonPlanId != null &&
                !_contentWasEdited,
            isRegeneratingAll: _regeneratingField == 'all',
            isLoadingLimits: _isLoadingLimits,
            primaryColor: primaryColor,
            filePath: filePath,
            isDownloading: _isDownloading,
            fieldDefinitions: _lessonPlanFields,
            getFieldValue: getFieldValue,
            getFieldRegenInfo: getFieldRegenInfo,
            stripHtml: stripHtml,
            onRegenAllTap: _showRegenAllDialog,
            onFieldRegenTap: _showRegenFieldDialog,
            onFileDownloadTap: downloadAndOpenFile,
          );
  }

  // Mixin property implementations
  @override
  Map<String, dynamic> get lessonPlanData => _lessonPlanData;
  @override
  set lessonPlanData(Map<String, dynamic> v) => _lessonPlanData = v;

  @override
  Map<String, dynamic> get regenLimits => _regenLimits;
  @override
  set regenLimits(Map<String, dynamic> v) => _regenLimits = v;

  @override
  bool get isLoadingLimits => _isLoadingLimits;
  @override
  set isLoadingLimits(bool v) => setState(() => _isLoadingLimits = v);

  @override
  String? get regeneratingField => _regeneratingField;
  @override
  set regeneratingField(String? v) => _regeneratingField = v;

  @override
  String get editedContent => _editedContent;
  @override
  set editedContent(String v) => _editedContent = v;

  @override
  bool get isSavingState => _isSaving;
  @override
  set isSavingState(bool v) => _isSaving = v;

  @override
  bool get isMounted => mounted;
  @override
  List<Map<String, String>> get lessonPlanFields => _lessonPlanFields;
  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  @override
  String? get lessonPlanId {
    final id =
        _lessonPlanData['id'] ??
        _lessonPlanData['rpp_id'] ??
        _lessonPlanData['lesson_plan_id'];
    return id?.toString();
  }

  @override
  bool get isDownloading => _isDownloading;
  @override
  set isDownloading(bool v) => setState(() => _isDownloading = v);

  @override
  String? get filePath {
    final url = _lessonPlanData['file_url'];
    final fp = _lessonPlanData['file_path'];
    AppLogger.debug(
      'lesson_plan',
      'filePath check — file_url: $url, '
      'file_path: $fp',
    );
    // Prefer file_url (full URL resolved by backend).
    if (url != null && url.toString().trim().isNotEmpty) {
      return url.toString().trim();
    }
    // Fall back to raw file_path.
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }


  @override
  String getFieldValue(String key, String altKey) {
    final val = _lessonPlanData[key];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    if (altKey.isNotEmpty) {
      final altVal = _lessonPlanData[altKey];
      if (altVal != null && altVal.toString().trim().isNotEmpty) {
        return altVal.toString().trim();
      }
    }
    return '';
  }

  @override
  Map<String, dynamic>? getFieldRegenInfo(String fieldKey) {
    if (_regenLimits.isEmpty) return null;
    final fields = _regenLimits['fields'] ?? _regenLimits;
    return (fields is Map) ? fields[fieldKey] as Map<String, dynamic>? : null;
  }

  @override
  Future<void> loadRegenLimits() async {
    final planId = lessonPlanId;
    if (planId == null) return;
    setState(() => _isLoadingLimits = true);
    try {
      final result = await getIt<ApiSubjectService>().getLessonPlanRegenLimits(
        planId,
      );
      if (mounted) {
        Map<String, dynamic> parsed = {};
        if (result is Map<String, dynamic>) {
          final data = result['data'];
          if (data is Map<String, dynamic>) {
            parsed = data;
          } else if (data == null) {
            parsed = result;
          }
        }
        setState(() {
          _regenLimits = parsed;
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  @override
  void _setSaving(bool value) => setState(() => _isSaving = value);

  @override
  void onSaveSuccess() {
    setState(() {
      _isEditing = false;
      // The just-saved content IS the official content now, so the
      // dirty flag must reset. Otherwise `canRegen` stays false and
      // the preview falls back to the plain formatted-content view
      // (no Regenerasi Semua Field banner, no per-section cards) until
      // the user manually refreshes the screen.
      _contentWasEdited = false;
      // Reformat the editor content from the latest lessonPlanData so
      // the formatted-content fallback (used when canRegen is false
      // for non-AI plans) also reflects the new values.
      _editedContent = formatLessonPlanContent();
    });
  }

  /// True when this RPP was created via manual file upload
  /// (not AI-generated).
  bool get _isManualUpload {
    // Explicit AI flag from backend
    final aiFlag = _lessonPlanData['ai_generated'] ??
        _lessonPlanData['is_ai_generated'];
    if (aiFlag == true || aiFlag == 'true' || aiFlag == '1') {
      return false;
    }
    // Has a file attachment → manual upload
    if (filePath != null) return true;
    // No AI content fields filled → manual
    return !hasAiAdditionalData;
  }

  // Private UI methods
  void _toggleEdit() {
    if (_isManualUpload) {
      // Manual upload RPP → open the upload form dialog
      _openManualEditForm();
    } else {
      // AI-generated RPP → inline structured editor
      setState(() => _isEditing = !_isEditing);
    }
  }

  void _openManualEditForm() {
    final teacherId =
        (_lessonPlanData['teacher_id'] ??
                _lessonPlanData['teacher']?['id'] ??
                '')
            .toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: LessonPlanFormDialog(
          teacherId: teacherId,
          lessonPlanData: _lessonPlanData,
          onSaved: () {
            // Close the detail sheet — the list screen
            // will reload and show updated data.
            AppNavigator.pop(context);
          },
        ),
      ),
    );
  }

  void _updateContent(String newContent) {
    setState(() {
      _editedContent = newContent;
      _contentWasEdited = true;
    });
  }

  void _updateField(String fieldKey, String value) {
    setState(() {
      _lessonPlanData[fieldKey] = value;
      _contentWasEdited = true;
      _editedContent = formatLessonPlanContent();
    });
  }

  void _showExportMenu() {
    showExportMenu(onWordExport: exportToWord, onTextExport: exportToText);
  }

  Future<void> _showRegenFieldDialog(String fieldKey, String fieldLabel) async {
    await showRegenFieldDialog(
      fieldKey,
      fieldLabel,
      LessonPlanRegenSheet.getAdditionalInstructions,
      regenerateField,
    );
  }

  Future<void> _showRegenAllDialog() async {
    await showRegenAllDialog(
      LessonPlanRegenSheet.showRegenAllDialog,
      regenerateAllFields,
    );
  }
}
