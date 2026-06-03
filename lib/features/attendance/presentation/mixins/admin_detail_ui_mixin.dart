import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for header UI building in AdminAttendanceDetailPage
mixin AdminDetailUiMixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Student> get studentList;
  bool get isEditing;

  Color getPrimaryColor();
  LinearGradient getCardGradient();
  Future<void> loadData();
  Future<void> saveChanges();
  String getStudentStatusFromData(String studentId);

  Widget buildHeader(BuildContext context, LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeaderActions(languageProvider),
          const SizedBox(height: AppSpacing.md),
          buildHeaderDateInfo(),
        ],
      ),
    );
  }

  Widget buildHeaderActions(LanguageProvider languageProvider) {
    return Row(
      children: [
        buildBackButton(),
        const SizedBox(width: AppSpacing.md),
        buildHeaderTitle(languageProvider),
        buildEditButton(),
        const SizedBox(width: AppSpacing.sm),
        if (!isEditing) buildMenuButton(languageProvider),
      ],
    );
  }

  Widget buildMenuButton(LanguageProvider languageProvider) {
    return PopupMenuButton<String>(
      onSelected: _handleMenuSelection,
      icon: _buildMenuIcon(),
      itemBuilder: (context) => _buildMenuItems(languageProvider),
    );
  }

  void _handleMenuSelection(String value) {
    if (value == 'refresh') loadData();
    if (value == 'export') {
      (this as dynamic).exportDetail();
    }
  }

  Widget _buildMenuIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    LanguageProvider languageProvider,
  ) {
    return [
      PopupMenuItem(
        value: 'export',
        child: _buildExportMenuItem(languageProvider),
      ),
      PopupMenuItem(
        value: 'refresh',
        child: _buildRefreshMenuItem(languageProvider),
      ),
    ];
  }

  Widget _buildExportMenuItem(LanguageProvider languageProvider) {
    return Row(
      children: [
        const Icon(Icons.file_download, size: 20),
        const SizedBox(width: 8),
        Text(
          languageProvider.getTranslatedText({
            'en': 'Export to Excel',
            'id': 'Export ke Excel',
          }),
        ),
      ],
    );
  }

  Widget _buildRefreshMenuItem(LanguageProvider languageProvider) {
    return Row(
      children: [
        const Icon(Icons.refresh, size: 20),
        const SizedBox(width: 8),
        Text(
          languageProvider.getTranslatedText({
            'en': 'Refresh',
            'id': 'Refresh',
          }),
        ),
      ],
    );
  }

  Widget buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (isEditing) {
          setState(() {
            (this as dynamic)._isEditing = false;
            for (final s in studentList) {
              (this as dynamic)._tempAttendanceStatus[s.id] =
                  getStudentStatusFromData(s.id);
            }
          });
        } else {
          AppNavigator.pop(context);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(
          isEditing ? Icons.close : Icons.arrow_back,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget buildHeaderTitle(LanguageProvider languageProvider) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing
                ? languageProvider.getTranslatedText({
                    'en': 'Edit Attendance',
                    'id': 'Edit Absensi',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Attendance Details',
                    'id': 'Detail Absensi',
                  }),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            widget.subjectName,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget buildEditButton() {
    return GestureDetector(
      onTap: () {
        if (isEditing) {
          saveChanges();
        } else {
          setState(() => (this as dynamic)._isEditing = true);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(
          isEditing ? Icons.check : Icons.edit,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget buildHeaderDateInfo() {
    return Row(
      children: [
        Icon(
          Icons.calendar_today,
          size: 14,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Text(
          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(widget.date),
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        if (widget.lessonHourName != null &&
            widget.lessonHourName!.isNotEmpty) ...[
          Text(
            ' • ',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          Text(
            widget.lessonHourName!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
