import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_dialog_field.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_utils_mixin.dart';

mixin LessonPlanAiResultRegenerateMixin
    on
        State<LessonPlanAiResultScreen>,
        LessonPlanAiResultUtilsMixin,
        LessonPlanAiResultDataMixin {
  // State
  bool _isRegenerating = false;
  final TextEditingController _promptController = TextEditingController();

  // Getter and setter for protected access
  bool get isRegenerating => _isRegenerating;
  set isRegenerating(bool value) => _isRegenerating = value;

  void showRegenerateDialog() {
    _promptController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: _buildRegenerateDialogTitle(),
        content: SingleChildScrollView(child: _buildRegenerateDialogContent()),
        actions: _buildRegenerateDialogActions(),
      ),
    );
  }

  Widget _buildRegenerateDialogTitle() {
    return Row(
      children: [
        Icon(Icons.auto_awesome, color: ColorUtils.primary),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'Generate Ulang AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildRegenerateDialogContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sistem akan menyusun ulang konten RPP berdasarkan '
          'data saat ini. Anda dapat menambahkan instruksi '
          'spesifik di bawah.',
          style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.lg),
        LessonPlanDialogField(
          label: 'Mata Pelajaran',
          value: subjectNameController.text,
        ),
        const SizedBox(height: AppSpacing.md),
        LessonPlanDialogField(label: 'Bab', value: chapterController.text),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Instruksi / Prompt Tambahan (Opsional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildPromptTextField(),
      ],
    );
  }

  Widget _buildPromptTextField() {
    return TextField(
      controller: _promptController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText:
            'Contoh: Buat kegiatan inti menggunakan metode '
            'diskusi kelompok dan studi kasus...',
        hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.primary),
        ),
      ),
    );
  }

  List<Widget> _buildRegenerateDialogActions() {
    return [
      TextButton(
        onPressed: () => AppNavigator.pop(context),
        child: Text(
          AppLocalizations.cancel.tr,
          style: TextStyle(color: ColorUtils.slate500),
        ),
      ),
      ElevatedButton(
        onPressed: () {
          AppNavigator.pop(context);
          _regenerateLessonPlan(prompt: _promptController.text);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorUtils.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        child: const Text('Generate'),
      ),
    ];
  }

  Future<void> _regenerateLessonPlan({String prompt = ''}) async {
    setState(() => _isRegenerating = true);
    try {
      AppLogger.debug('lesson_plan', 'Regenerating with prompt: $prompt');
      await Future.delayed(const Duration(seconds: 2));
      final regeneratedData = _buildRegeneratedContent();
      _updateRegeneratedControllers(regeneratedData);
      _showRegenerationSuccess();
    } catch (e) {
      _handleRegenerationError(e);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Map<String, String> _buildRegeneratedContent() {
    return {
      'title': titleController.text,
      'learning_objective':
          '<ol><li>[Regenerated] Melalui diskusi, siswa dapat '
          'memahami konsep dengan lebih mendalam.</li><li>Diberikan '
          'studi kasus, siswa mampu memecahkan masalah dengan '
          'akurat.</li></ol>',
      'learning_activities':
          '<h3>Pendahuluan (15 menit)</h3><p>[Regenerated] Guru '
          'membuka kelas dengan cerita inspiratif terkait materi.'
          '</p><h3>Kegiatan Inti (60 menit)</h3><ul><li>Siswa '
          'melakukan debat aktif mengenai topik.</li><li>Siswa '
          'menyusun mind-map bersama kelompok.</li></ul>'
          '<h3>Penutup (15 menit)</h3><p>Evaluasi singkat dan '
          'refleksi bersama.</p>',
      'assessment':
          '<h3>1. Penilaian Kinerja</h3><p>[Regenerated] Observasi '
          'terhadap keaktifan siswa dalam berdebat.</p>'
          '<h3>2. Penilaian Produk</h3><p>Penilaian kreativitas '
          'mind-map yang dihasilkan kelompok.</p>',
    };
  }

  void _updateRegeneratedControllers(Map<String, String> data) {
    setState(() {
      objectivesController.document = convertHtmlToQuill(
        data['learning_objective']!,
      );
      coreActivityController.document = convertHtmlToQuill(
        data['learning_activities']!,
      );
      assessmentController.document = convertHtmlToQuill(data['assessment']!);
    });
  }

  void _showRegenerationSuccess() {
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        AppLocalizations.lessonPlanRegeneratedSuccessfully.tr,
      );
    }
  }

  void _handleRegenerationError(dynamic e) {
    AppLogger.error('lesson_plan', e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.failedToRegenerateLessonPlan.tr}: $e',
          ),
        ),
      );
    }
  }

  void disposeRegenerateResources() {
    _promptController.dispose();
  }
}
