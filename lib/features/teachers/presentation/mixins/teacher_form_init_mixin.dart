import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Handles initialization and cleanup of teacher form state
mixin TeacherFormInitMixin on ConsumerState<TeacherFormDialog> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController nipController;
  late TextEditingController phoneController;

  String? selectedGender;
  String? selectedWaliKelasId;
  String? selectedStatus;
  List<String> selectedSubjectIds = [];
  List<String> selectedClassIds = [];
  bool isChangeUserMode = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeGender();
    _initializeHomeroomClass();
    _initializeEmploymentStatus();
    _initializeSubjectsAndClasses();
  }

  void _initializeControllers() {
    final model = widget.teacher != null
        ? Teacher.fromJson(widget.teacher!)
        : null;
    nameController = TextEditingController(text: model?.name ?? '');
    emailController = TextEditingController(text: model?.email ?? '');
    nipController = TextEditingController(text: model?.employeeNumber ?? '');
    // Phone number — accept either `phone` or `phone_number` from the
    // backend payload so legacy + new responses both populate.
    final rawPhone =
        widget.teacher?['phone_number'] ??
        widget.teacher?['phone'] ??
        widget.teacher?['no_hp'];
    phoneController = TextEditingController(text: rawPhone?.toString() ?? '');
  }

  void _initializeGender() {
    selectedGender = widget.teacher?['gender']?.toString();
  }

  void _initializeHomeroomClass() {
    // Homeroom ID logic
    if (widget.teacher != null) {
      if (widget.teacher!['homeroom_class'] != null &&
          widget.teacher!['homeroom_class'] is Map) {
        selectedWaliKelasId = widget.teacher!['homeroom_class']['id']
            ?.toString();
      } else if (widget.teacher!['homeroom_classes'] != null &&
          widget.teacher!['homeroom_classes'] is List &&
          (widget.teacher!['homeroom_classes'] as List).isNotEmpty) {
        selectedWaliKelasId = widget.teacher!['homeroom_classes'][0]['id']
            ?.toString();
      } else {
        selectedWaliKelasId = widget.teacher!['homeroom_class_id']?.toString();
      }
    }

    // Validate selectedWaliKelasId
    if (selectedWaliKelasId != null) {
      final exists = widget.classes.any(
        (c) => c['id']?.toString() == selectedWaliKelasId && c['name'] != null,
      );
      if (!exists) {
        selectedWaliKelasId = null;
      }
    }
  }

  void _initializeEmploymentStatus() {
    // Normalize employment_status
    final String? rawStatus = widget.teacher?['employment_status']?.toString();
    if (rawStatus != null) {
      final statusMap = {
        'Tetap': 'permanent',
        'Kontrak': 'contract',
        'Honor': 'temporary',
        'permanent': 'permanent',
        'contract': 'contract',
        'temporary': 'temporary',
      };
      selectedStatus = statusMap[rawStatus] ?? rawStatus;
    }
  }

  void _initializeSubjectsAndClasses() {
    // Parse project IDs
    if (widget.teacher != null) {
      if (widget.teacher!['subjects'] != null &&
          widget.teacher!['subjects'] is List) {
        selectedSubjectIds = (widget.teacher!['subjects'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (widget.teacher!['subject_ids'] != null) {
        final idsString = widget.teacher!['subject_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedSubjectIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }

      if (widget.teacher!['classes'] != null &&
          widget.teacher!['classes'] is List) {
        selectedClassIds = (widget.teacher!['classes'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (widget.teacher!['class_ids'] != null) {
        final idsString = widget.teacher!['class_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedClassIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    nipController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
