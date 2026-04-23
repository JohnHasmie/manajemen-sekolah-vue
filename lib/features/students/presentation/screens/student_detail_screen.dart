// Student detail screen - full profile with loading/error states.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_data_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_formatting_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_ui_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_state_builder_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_detail_header_mixin.dart';

/// Student detail screen - displays full profile for a single student.
///
/// Takes a [student] map (basic data) and fetches full details from API.
/// Optionally accepts [onEdit] callback to trigger refresh in parent screen.
class StudentDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback? onEdit;

  const StudentDetailScreen({super.key, required this.student, this.onEdit});

  @override
  StudentDetailScreenState createState() => StudentDetailScreenState();
}

/// Mutable state for [StudentDetailScreen].
///
/// Manages loading state, error handling, and student data display.
/// Uses mixins for data loading, formatting, and UI building.
class StudentDetailScreenState extends ConsumerState<StudentDetailScreen>
    with
        StudentDetailDataMixin,
        StudentDetailFormattingMixin,
        StudentDetailUiMixin,
        StudentDetailUiBuilderMixin,
        StudentDetailStateBuilderMixin,
        StudentDetailHeaderMixin {
  Map<String, dynamic>? _studentDetail;
  bool _isLoading = true;
  String? _errorMessage;

  // Implement StudentDetailDataMixin properties
  @override
  Map<String, dynamic>? get studentDetail => _studentDetail;
  @override
  set studentDetail(Map<String, dynamic>? value) => _studentDetail = value;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String? get errorMessage => _errorMessage;
  @override
  set errorMessage(String? value) => _errorMessage = value;

  /// Fetches full student details from API.
  @override
  void initState() {
    super.initState();
    _loadStudentDetail();
  }

  /// Wrapper for mixin's loadStudentDetail method.
  void _loadStudentDetail() {
    loadStudentDetail(studentId: Student.fromJson(widget.student).id);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final student = _studentDetail ?? widget.student;
    final classes = student['classes'] as List<dynamic>? ?? [];
    final nameStr = Student.fromJson(student).name;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeader(
            context,
            languageProvider,
            nameStr,
            onRefresh: _loadStudentDetail,
            onEdit: widget.onEdit != null
                ? () {
                    AppNavigator.pop(context);
                    widget.onEdit?.call();
                  }
                : null,
          ),
          Expanded(
            child: _buildBodyContent(languageProvider, student, classes),
          ),
        ],
      ),
    );
  }

  /// Builds body content based on loading/error/success states.
  Widget _buildBodyContent(
    LanguageProvider languageProvider,
    Map<String, dynamic> student,
    List<dynamic> classes,
  ) {
    if (_isLoading) {
      return buildLoadingState(languageProvider);
    }
    if (_errorMessage != null) {
      return buildErrorState(
        languageProvider,
        _errorMessage,
        _loadStudentDetail,
      );
    }
    return _buildScrollableContent(languageProvider, student, classes);
  }

  /// Builds scrollable content with all info cards.
  Widget _buildScrollableContent(
    LanguageProvider languageProvider,
    Map<String, dynamic> student,
    List<dynamic> classes,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildProfileHeaderCard(student),
          const SizedBox(height: AppSpacing.lg),
          buildPersonalInfoCard(languageProvider, student),
          if (classes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            buildClassHistoryCard(languageProvider, classes),
          ],
          const SizedBox(height: AppSpacing.md),
          buildParentInfoCard(languageProvider, student),
          const SizedBox(height: AppSpacing.xxl),
          buildBackButton(context, languageProvider),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
