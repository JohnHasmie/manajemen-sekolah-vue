import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_utils_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_save_mixin.dart';

mixin LessonPlanAiResultPollingMixin
    on
        State<LessonPlanAiResultScreen>,
        LessonPlanAiResultUtilsMixin,
        LessonPlanAiResultDataMixin,
        LessonPlanAiResultSaveMixin {
  // State
  bool _isPolling = false;
  String _pollingStatus = '';
  String? _pollingError;

  // Getters and setters for protected access
  bool get isPolling => _isPolling;
  set isPolling(bool value) => _isPolling = value;

  String get pollingStatus => _pollingStatus;
  set pollingStatus(String value) => _pollingStatus = value;

  String? get pollingError => _pollingError;
  set pollingError(String? value) => _pollingError = value;

  Future<void> startPolling() async {
    _initPolling();
    final widget = this.widget as dynamic;
    final jobIdForPoll = _validateAndGetJobId(widget);
    if (jobIdForPoll == null) return;

    AppLogger.debug('lesson_plan', 'Starting polling for job: $jobIdForPoll');
    int attempts = 0;
    const maxAttempts = 60;

    while (attempts < maxAttempts) {
      if (!mounted) return;
      // Break early if polling was completed
      if (!_isPolling) return;
      attempts++;

      try {
        AppLogger.debug('lesson_plan', 'Poll attempt #$attempts');
        await _processPollAttempt(jobIdForPoll, widget, attempts);
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }

      await Future.delayed(const Duration(seconds: 5));
    }
    if (_isPolling) _handlePollingTimeout();
  }

  void _initPolling() {
    if (mounted) {
      setState(() {
        _isPolling = true;
        _pollingStatus = 'Menyusun kompetensi dan tujuan pembelajaran...';
      });
    }
  }

  String? _validateAndGetJobId(dynamic widget) {
    if (widget.pollUrl == null && widget.jobId == null) {
      AppLogger.error('lesson_plan', 'No poll_url or job_id available');
      _setPollingError(
        'Server tidak mengembalikan informasi polling '
        '(poll_url/job_id null). Silakan coba lagi.',
      );
      return null;
    }

    final jobIdForPoll = widget.jobId ?? widget.pollUrl?.split('/').last;
    if (jobIdForPoll == null) {
      _setPollingError('Tidak dapat menentukan job ID untuk polling.');
      return null;
    }
    return jobIdForPoll;
  }

  Future<void> _processPollAttempt(
    String jobIdForPoll,
    dynamic widget,
    int attempts,
  ) async {
    final response = await getIt<ApiSubjectService>().pollAiJob(
      jobIdForPoll,
      widget.token ?? '',
    );

    if (!mounted) return;

    AppLogger.debug(
      'lesson_plan',
      'Poll response status: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      _handleStatusResponse(response.data);
    } else if (response.statusCode == 202) {
      _updatePollingStatus('AI masih memproses...');
    }
  }

  void _handleStatusResponse(dynamic responseData) {
    final resultBody = responseData is Map<String, dynamic>
        ? responseData
        : <String, dynamic>{};
    final jobData = resultBody['data'] ?? resultBody;
    final status = jobData['status'] ?? resultBody['status'];

    if (status == 'completed' || status == 'success') {
      final lessonPlanResponse =
          jobData['result'] ??
          jobData['data'] ??
          resultBody['result'] ??
          resultBody;
      _applyPollingResult(lessonPlanResponse);
    } else if (status == 'failed' || status == 'error') {
      _setPollingError(
        jobData['error_message'] ??
            jobData['error'] ??
            resultBody['message'] ??
            'AI generation failed',
      );
    } else {
      final statusLabel = status == 'processing'
          ? 'AI sedang menyusun RPP...'
          : 'Menunggu antrian AI...';
      _updatePollingStatus(statusLabel);
    }
  }

  void _updatePollingStatus(String status) {
    if (mounted) setState(() => _pollingStatus = status);
  }

  void _setPollingError(String error) {
    if (mounted) {
      setState(() {
        _isPolling = false;
        _pollingError = error;
      });
    }
  }

  void _handlePollingTimeout() {
    if (mounted) {
      setState(() {
        _isPolling = false;
        _pollingError = 'Waktu tunggu AI habis (5 menit). Silakan coba lagi.';
      });
    }
  }

  void _applyPollingResult(dynamic lessonPlanResponse) {
    final widget = this.widget as dynamic;
    final metadata = widget.pollingMetadata ?? <String, dynamic>{};

    // Extract the AI-backend lesson plan ID
    final aiId = lessonPlanResponse['id']?.toString();
    if (aiId != null) {
      lessonPlanAiId = aiId;
      AppLogger.info('lesson_plan', 'AI lesson plan ID: $aiId');
    }

    setState(() {
      _isPolling = false;
      _pollingError = null;
    });

    // Build mapped data and navigate to detail/preview
    final lessonPlanData = _buildPolledLessonPlanData(
      lessonPlanResponse,
      Map<String, dynamic>.from(metadata),
    );
    handleGenerationComplete(lessonPlanData: lessonPlanData);
  }

  Map<String, dynamic> _buildPolledLessonPlanData(
    dynamic response,
    Map<String, dynamic> metadata,
  ) {
    final widget = this.widget as LessonPlanAiResultScreen;
    return {
      'id': response['id'],
      'teacher_id': widget.teacherId,
      'title': response['title'] ?? metadata['title'] ?? 'Lesson Plan AI',
      'mata_pelajaran_id': metadata['mata_pelajaran_id'],
      'mata_pelajaran_nama': metadata['mata_pelajaran_nama'] ?? '',
      'satuan_pendidikan': metadata['satuan_pendidikan'] ?? 'SD/MI',
      'bab_nama': metadata['bab_nama'] ?? '',
      'sub_bab_nama': metadata['sub_bab_nama'] ?? '',
      'kelas_semester': metadata['kelas_semester'] ?? '',
      'tema': response['title'],
      'sub_tema': '',
      'pembelajaran_ke': '',
      'alokasi_waktu': metadata['alokasi_waktu'] ?? '',
      'kompetensi_inti': stripHtml(
        response['core_competence'] as String? ?? '',
      ),
      'kompetensi_dasar': stripHtml(
        response['basic_competence'] as String? ?? '',
      ),
      'tujuan_pembelajaran': stripHtml(
        response['learning_objective'] as String? ?? '',
      ),
      'kegiatan_inti': stripHtml(
        response['learning_activities'] as String? ?? '',
      ),
      'penilaian': stripHtml(response['assessment'] as String? ?? ''),
      'is_ai_generated': true,
    };
  }
}
