// The "Add Attendance" tab body: form + toolbar + student list + submit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/attendance_input_toolbar_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class AttendanceInputMode extends ConsumerStatefulWidget {
  final bool isLoadingInput;
  final Widget inputFormWidget;
  final String? selectedSubjectId;
  final List<Student> filteredStudentList;
  final Map<String, String> attendanceStatus;
  final bool isSubmitting;
  final Color primaryColor;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onQuickActionsPressed;
  final void Function(String studentId, String status) onStatusChanged;
  final VoidCallback onSubmit;
  final ScrollController? scrollController;
  final bool compactMode;

  /// Optional widget rendered between the toolbar and the student list.
  /// Used by the embedded sheet (Frame A) for the "Daftar Siswa · N
  /// siswa" section head — pass null for the standalone screen.
  final Widget? sectionHead;

  const AttendanceInputMode({
    super.key,
    required this.isLoadingInput,
    required this.inputFormWidget,
    required this.selectedSubjectId,
    required this.filteredStudentList,
    required this.attendanceStatus,
    required this.isSubmitting,
    required this.primaryColor,
    required this.searchController,
    required this.onSearchChanged,
    required this.onQuickActionsPressed,
    required this.onStatusChanged,
    required this.onSubmit,
    this.scrollController,
    this.compactMode = false,
    this.sectionHead,
  });

  @override
  ConsumerState<AttendanceInputMode> createState() =>
      _AttendanceInputModeState();
}

class _AttendanceInputModeState extends ConsumerState<AttendanceInputMode>
    with AttendanceInputToolbarMixin {
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (widget.isLoadingInput) {
      return const SkeletonListLoading(itemCount: 4, infoTagCount: 1);
    }

    // When embedded in a DraggableScrollableSheet, the scroll
    // controller MUST drive the primary scrollable. Using a Column
    // with the ListView inside Expanded and the submit button
    // outside causes gesture conflicts — the sheet's drag
    // recogniser swallows taps on the button.
    //
    // Fix: use CustomScrollView so *everything* (form, toolbar,
    // student list, submit button) lives inside one scrollable
    // driven by the sheet's controller.
    if (widget.scrollController != null) {
      return CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          // 1. Form Section
          SliverToBoxAdapter(child: widget.inputFormWidget),

          // 2. Toolbar
          if (widget.selectedSubjectId != null)
            SliverToBoxAdapter(child: buildToolbar()),

          // 2b. Section head (Frame A — "Daftar Siswa · N siswa")
          if (widget.sectionHead != null &&
              widget.selectedSubjectId != null &&
              widget.filteredStudentList.isNotEmpty)
            SliverToBoxAdapter(child: widget.sectionHead!),

          // 3. Student List (or empty state)
          _buildStudentListSliver(languageProvider),

          // 4. Submit Button
          if (widget.selectedSubjectId != null &&
              widget.filteredStudentList.isNotEmpty)
            SliverToBoxAdapter(child: _buildSubmitButton(languageProvider)),
        ],
      );
    }

    // Non-embedded (standalone screen): keep the original
    // Column layout with a fixed bottom button.
    return Column(
      children: [
        // 1. Form Section
        widget.inputFormWidget,

        // 2. Toolbar
        if (widget.selectedSubjectId != null) buildToolbar(),

        // 2b. Section head (Frame A — "Daftar Siswa · N siswa")
        if (widget.sectionHead != null &&
            widget.selectedSubjectId != null &&
            widget.filteredStudentList.isNotEmpty)
          widget.sectionHead!,

        // 3. Student List
        Expanded(child: _buildStudentListSection(languageProvider)),

        // 4. Submit Button
        if (widget.selectedSubjectId != null &&
            widget.filteredStudentList.isNotEmpty)
          _buildSubmitButton(languageProvider),
      ],
    );
  }

  /// Builds the student list as a Sliver (for CustomScrollView).
  Widget _buildStudentListSliver(LanguageProvider lang) {
    if (widget.selectedSubjectId == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildNoSubjectSelected(lang),
      );
    }

    if (widget.filteredStudentList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          title: lang.getTranslatedText({
            'en': 'No Students',
            'id': 'Tidak ada siswa',
          }),
          subtitle: lang.getTranslatedText({
            'en': 'No students found for selected class',
            'id':
                'Tidak ada siswa untuk kelas yang '
                'dipilih',
          }),
          icon: Icons.people_outline,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 4),
      sliver: SliverList.builder(
        itemCount: widget.filteredStudentList.length,
        itemBuilder: (context, index) {
          final student = widget.filteredStudentList[index];
          return AttendanceStudentItem(
            student: student,
            currentStatus: widget.attendanceStatus[student.id] ?? 'hadir',
            languageProvider: lang,
            onStatusChanged: widget.onStatusChanged,
            index: index,
            compactMode: widget.compactMode,
          );
        },
      ),
    );
  }

  /// Builds the student list or empty state (for Column layout).
  Widget _buildStudentListSection(LanguageProvider lang) {
    if (widget.selectedSubjectId == null) {
      return _buildNoSubjectSelected(lang);
    }

    if (widget.filteredStudentList.isEmpty) {
      return EmptyState(
        title: lang.getTranslatedText({
          'en': 'No Students',
          'id': 'Tidak ada siswa',
        }),
        subtitle: lang.getTranslatedText({
          'en': 'No students found for selected class',
          'id':
              'Tidak ada siswa untuk kelas yang '
              'dipilih',
        }),
        icon: Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: widget.filteredStudentList.length,
      itemBuilder: (context, index) {
        final student = widget.filteredStudentList[index];
        return AttendanceStudentItem(
          student: student,
          currentStatus: widget.attendanceStatus[student.id] ?? 'hadir',
          languageProvider: lang,
          onStatusChanged: widget.onStatusChanged,
          index: index,
          compactMode: widget.compactMode,
        );
      },
    );
  }

  /// Builds the empty state when no subject is selected.
  Widget _buildNoSubjectSelected(LanguageProvider lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 56,
              color: ColorUtils.slate300,
            ),
            const SizedBox(height: 16),
            Text(
              lang.getTranslatedText({
                'en':
                    'Please select Class and Subject '
                    'first',
                'id':
                    'Silakan pilih Kelas dan Mapel '
                    'terlebih dahulu',
              }),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              lang.getTranslatedText({
                'en':
                    'Or ensure you have a schedule '
                    'for the selected date',
                'id':
                    'Atau pastikan anda memiliki '
                    'jadwal pada tanggal yang dipilih',
              }),
              style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the submit button with loading state.
  Widget _buildSubmitButton(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _buildSubmitButtonContent(lang),
          ),
        ),
      ),
    );
  }

  /// Builds the submit button content.
  Widget _buildSubmitButtonContent(LanguageProvider lang) {
    return ElevatedButton.icon(
      onPressed: widget.isSubmitting ? null : widget.onSubmit,
      icon: _buildButtonIcon(),
      label: _buildButtonLabel(lang),
      style: _buildButtonStyle(),
    );
  }

  /// Builds the button icon.
  Widget _buildButtonIcon() {
    if (widget.isSubmitting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return const Icon(Icons.save_outlined, size: 18);
  }

  /// Builds the button label.
  Widget _buildButtonLabel(LanguageProvider lang) {
    return Text(
      widget.isSubmitting
          ? lang.getTranslatedText({'en': 'Saving...', 'id': 'Menyimpan...'})
          : lang.getTranslatedText({
              'en': 'Save Attendance',
              'id': 'Simpan Absensi',
            }),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  /// Builds the button style.
  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: widget.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    );
  }

  // ============ Mixin Implementation ============

  @override
  LanguageProvider get toolbarLanguage => ref.watch(languageRiverpod);

  @override
  Color get toolbarPrimaryColor => widget.primaryColor;

  @override
  List<dynamic> get toolbarFilteredStudents => widget.filteredStudentList;

  @override
  Map<String, String> get toolbarAttendanceStatus => widget.attendanceStatus;

  @override
  VoidCallback get onToolbarSearchChanged => widget.onSearchChanged;

  @override
  VoidCallback get onToolbarQuickActionsPressed => widget.onQuickActionsPressed;

  @override
  TextEditingController get toolbarSearchController => widget.searchController;
}
