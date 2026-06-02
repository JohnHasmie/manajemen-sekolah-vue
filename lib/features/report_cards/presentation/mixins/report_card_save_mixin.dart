import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for save and sync operations.
mixin ReportCardSaveMixin on ConsumerState<ReportCardDetailScreen> {
  Future<void> saveReportCard({String status = 'draft'}) async {
    setState(() {
      isSaving = true;
    });

    try {
      final academicYearId = getAcademicYearIdForSave() ?? '';
      final semesterId = await resolveAcademicTermForSave();

      final payload = {
        'student_class_id': widget.studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
        // Backend rename (rename guide §4): predicate columns now accept
        // canonical English words `very_good` / `good` / `fair` / `poor`
        // (plus the letter grades A/B/C/D). Map the Indonesian display
        // labels the form uses to those before sending.
        'spiritual_predicate': _toCanonicalPredicate(spiritualPredicate),
        'spiritual_description': spiritualDescCtrl.text,
        'social_predicate': _toCanonicalPredicate(socialPredicate),
        'social_description': socialDescCtrl.text,
        'attendance_sick': int.tryParse(sickCtrl.text) ?? 0,
        'attendance_permit': int.tryParse(permitCtrl.text) ?? 0,
        'attendance_absent': int.tryParse(absentCtrl.text) ?? 0,
        'homeroom_notes': notesCtrl.text,
        // Backend rename (rename guide §4): canonical promotion_decision
        // values are `promoted` / `not_promoted` / `graduated` /
        // `not_graduated` (was `Naik Kelas` / `Tidak Naik` / `Lulus`).
        'promotion_decision': _toCanonicalPromotionDecision(promotionDecision),
        'status': status,
        'subjects': subjects,
        'extracurriculars': extras,
        'achievements': achievements,
      };

      final response = await getIt<ApiReportCardService>().saveReportCard(
        payload,
      );

      if (response != null) {
        if (mounted) {
          setState(() {
            hasUnsavedChanges = false;
          });
          // Refresh dashboard so "Raport belum tuntas" priority-inbox
          // rows drop out of "Perlu perhatian" as soon as the wali
          // kelas saves a draft or finalizes the raport.
          unawaited(ref.read(dashboardProvider.notifier).refreshStats());
          SnackBarUtils.showInfo(
            context,
            status == 'final' ? 'Raport diselesaikan!' : 'Draft disimpan!',
          );
          if (status == 'final') {
            AppNavigator.pop(context, true);
          } else {
            existingRaport = response;
          }
        }
      } else {
        throw Exception('Failed to save report card');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  String? getAcademicYearIdForSave() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  Future<String> resolveAcademicTermForSave() async {
    // Canonical lesson_plans.semester is `even` (was `genap`). Accept
    // both so older cached values keep returning the correct id.
    bool isEvenSemester(dynamic raw) {
      final s = raw?.toString().toLowerCase();
      return s == 'even' || s == 'genap';
    }

    final cachedDayData = await LocalCacheService.load(
      'school_day_data',
      ttl: const Duration(hours: 24),
    );
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          isEvenSemester(cachedDayData['semester'])) {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await getIt<ApiScheduleService>()
        .getDateBasedSemester();
    if (dateBasedSemester.isNotEmpty) {
      await LocalCacheService.save('school_day_data', dateBasedSemester);
    }
    if (dateBasedSemester.containsKey('semester') &&
        isEvenSemester(dateBasedSemester['semester'])) {
      return '2';
    }
    return '1';
  }

  /// Map an Indonesian predicate label to the backend canonical English
  /// value. `Sangat Baik` / `Baik Sekali` → `very_good`, `Baik` →
  /// `good`, `Cukup` → `fair`, `Kurang` → `poor`. Letter grades and
  /// already-canonical English values pass through.
  String _toCanonicalPredicate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    switch (trimmed.toLowerCase()) {
      case 'sangat baik':
      case 'baik sekali':
      case 'very_good':
        return 'very_good';
      case 'baik':
      case 'good':
        return 'good';
      case 'cukup':
      case 'fair':
        return 'fair';
      case 'kurang':
      case 'poor':
        return 'poor';
      default:
        // Letter grades (A/B/C/D) and unknown values pass through.
        return trimmed;
    }
  }

  /// Map a possibly-legacy promotion_decision label to the backend
  /// canonical value. `Naik Kelas` → `promoted`, `Tidak Naik` /
  /// `Tinggal di Kelas` → `not_promoted`, `Lulus` → `graduated`,
  /// `Tidak Lulus` → `not_graduated`.
  String _toCanonicalPromotionDecision(String raw) {
    switch (raw.toLowerCase()) {
      case 'naik kelas':
      case 'promoted':
        return 'promoted';
      case 'tidak naik':
      case 'tinggal di kelas':
      case 'not_promoted':
        return 'not_promoted';
      case 'lulus':
      case 'graduated':
        return 'graduated';
      case 'tidak lulus':
      case 'not_graduated':
        return 'not_graduated';
      default:
        return raw;
    }
  }

  // Abstract declarations for state
  late bool isSaving;
  late bool hasUnsavedChanges;
  late String spiritualPredicate;
  late String socialPredicate;
  late String promotionDecision;
  late TextEditingController spiritualDescCtrl;
  late TextEditingController socialDescCtrl;
  late TextEditingController sickCtrl;
  late TextEditingController permitCtrl;
  late TextEditingController absentCtrl;
  late TextEditingController notesCtrl;
  late Map<String, dynamic>? existingRaport;
  late List<Map<String, dynamic>> subjects;
  late List<Map<String, dynamic>> extras;
  late List<Map<String, dynamic>> achievements;
}
