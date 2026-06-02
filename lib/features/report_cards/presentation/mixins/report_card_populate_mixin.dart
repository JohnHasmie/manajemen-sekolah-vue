import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for populating form fields from API data.
mixin ReportCardPopulateMixin on ConsumerState<ReportCardDetailScreen> {
  /// Map the backend canonical predicate (rename guide §4: `very_good`
  /// / `good` / `fair` / `poor`) back to the Indonesian label the form
  /// chips compare against. Letter grades (A/B/C/D) and unknown values
  /// pass through.
  String _displayPredicate(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return 'Baik';
    switch (s.toLowerCase()) {
      case 'very_good':
      case 'sangat baik':
      case 'baik sekali':
        return 'Sangat Baik';
      case 'good':
      case 'baik':
        return 'Baik';
      case 'fair':
      case 'cukup':
        return 'Cukup';
      case 'poor':
      case 'kurang':
        return 'Kurang';
      default:
        return s;
    }
  }

  void populateFromExisting(Map<String, dynamic> data) {
    spiritualPredicate = _displayPredicate(data['spiritual_predicate']);
    spiritualDescCtrl.text = data['spiritual_description'] ?? '';
    socialPredicate = _displayPredicate(data['social_predicate']);
    socialDescCtrl.text = data['social_description'] ?? '';

    sickCtrl.text = (data['attendance_sick'] ?? 0).toString();
    permitCtrl.text = (data['attendance_permit'] ?? 0).toString();
    absentCtrl.text = (data['attendance_absent'] ?? 0).toString();
    notesCtrl.text = data['homeroom_notes'] ?? '';
    // Backend canonical promotion_decision: `promoted` / `not_promoted`
    // / `graduated` / `not_graduated` (was `Naik Kelas` / `Tidak Naik` /
    // `Lulus`). Map back to the Indonesian display labels the chip
    // radio uses so the saved choice stays selected on re-open.
    final rawPromotion = (data['promotion_decision'] ?? '')
        .toString()
        .toLowerCase();
    promotionDecision = switch (rawPromotion) {
      'promoted' || 'naik kelas' => 'Naik Kelas',
      'not_promoted' ||
      'tidak naik' ||
      'tinggal di kelas' => 'Tinggal di Kelas',
      'graduated' || 'lulus' => 'Lulus',
      'not_graduated' || 'tidak lulus' => 'Tidak Lulus',
      _ => 'Naik Kelas',
    };

    // Backend rename (rename guide §1): `raport_subjects` table renamed
    // to `report_card_subjects`. Accept both keys so older API responses
    // keep populating.
    final reportCardSubjects =
        data['report_card_subjects'] ?? data['raport_subjects'];
    if (reportCardSubjects != null) {
      subjects = List<Map<String, dynamic>>.from(
        reportCardSubjects.map(
          (x) => {
            'subject_id': x['subject_id'],
            'subject_name': x['subject']?['name'] ?? 'Mapel',
            'knowledge_score': x['knowledge_score']?.toString() ?? '0',
            'knowledge_predicate': x['knowledge_predicate'] ?? '',
            'knowledge_description': x['knowledge_description'] ?? '',
            'skill_score': x['skill_score']?.toString() ?? '0',
            'skill_predicate': x['skill_predicate'] ?? '',
            'skill_description': x['skill_description'] ?? '',
          },
        ),
      );
    }

    if (data['extracurriculars'] != null) {
      extras = List<Map<String, dynamic>>.from(
        data['extracurriculars'].map(
          (x) => {
            'name': x['name'] ?? '',
            'score': x['score'] ?? '',
            'description': x['description'] ?? '',
          },
        ),
      );
    }

    if (data['achievements'] != null) {
      achievements = List<Map<String, dynamic>>.from(
        data['achievements'].map(
          (x) => {
            'name': x['name'] ?? '',
            'type': x['type'] ?? '',
            'description': x['description'] ?? '',
          },
        ),
      );
    }
  }

  void populateFromInitial(Map<String, dynamic> data) {
    if (data['attendance'] != null) {
      sickCtrl.text = (data['attendance']['sick'] ?? 0).toString();
      permitCtrl.text = (data['attendance']['permit'] ?? 0).toString();
      absentCtrl.text = (data['attendance']['absent'] ?? 0).toString();
    }

    if (data['grades'] != null) {
      subjects = List<Map<String, dynamic>>.from(
        data['grades'].map(
          (x) => {
            'subject_id': x['subject_id'],
            'subject_name': x['subject_name'] ?? 'Mapel',
            'knowledge_score': x['knowledge_score']?.toString() ?? '0',
            'knowledge_predicate': x['knowledge_predicate'] ?? '',
            'knowledge_description': x['knowledge_description'] ?? '',
            'skill_score': x['skill_score']?.toString() ?? '0',
            'skill_predicate': x['skill_predicate'] ?? '',
            'skill_description': x['skill_description'] ?? '',
            'recap_uh_avg': x['recap_uh_avg'],
            'recap_uts': x['recap_uts'],
            'recap_uas': x['recap_uas'],
            'recap_final_score': x['recap_final_score'],
            'recap_bab_scores': x['recap_bab_scores'] ?? [],
            'recap_bab_names': x['recap_bab_names'] ?? [],
          },
        ),
      );
    }
  }

  void syncSubjectsWithRecap(List<dynamic> initialGrades) {
    for (final recapItem in initialGrades) {
      final existingIndex = subjects.indexWhere(
        (s) => s['subject_id'] == recapItem['subject_id'],
      );
      if (existingIndex == -1) {
        subjects.add({
          'subject_id': recapItem['subject_id'],
          'subject_name': recapItem['subject_name'] ?? 'Mapel',
          'knowledge_score': recapItem['knowledge_score']?.toString() ?? '0',
          'knowledge_predicate': recapItem['knowledge_predicate'] ?? '',
          'knowledge_description': recapItem['knowledge_description'] ?? '',
          'skill_score': recapItem['skill_score']?.toString() ?? '0',
          'skill_predicate': recapItem['skill_predicate'] ?? '',
          'skill_description': recapItem['skill_description'] ?? '',
          'recap_uh_avg': recapItem['recap_uh_avg'],
          'recap_uts': recapItem['recap_uts'],
          'recap_uas': recapItem['recap_uas'],
          'recap_final_score': recapItem['recap_final_score'],
          'recap_bab_scores': recapItem['recap_bab_scores'] ?? [],
          'recap_bab_names': recapItem['recap_bab_names'] ?? [],
        });
      } else {
        subjects[existingIndex]['recap_uh_avg'] = recapItem['recap_uh_avg'];
        subjects[existingIndex]['recap_uts'] = recapItem['recap_uts'];
        subjects[existingIndex]['recap_uas'] = recapItem['recap_uas'];
        subjects[existingIndex]['recap_final_score'] =
            recapItem['recap_final_score'];
        subjects[existingIndex]['recap_bab_scores'] =
            recapItem['recap_bab_scores'] ?? [];
        subjects[existingIndex]['recap_bab_names'] =
            recapItem['recap_bab_names'] ?? [];
      }
    }
  }

  // Abstract declarations for state
  late String spiritualPredicate;
  late String socialPredicate;
  late String promotionDecision;
  late TextEditingController spiritualDescCtrl;
  late TextEditingController socialDescCtrl;
  late TextEditingController sickCtrl;
  late TextEditingController permitCtrl;
  late TextEditingController absentCtrl;
  late TextEditingController notesCtrl;
  late List<Map<String, dynamic>> subjects;
  late List<Map<String, dynamic>> extras;
  late List<Map<String, dynamic>> achievements;
}
