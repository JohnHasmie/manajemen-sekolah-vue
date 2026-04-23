// Bottom sheet modal for selecting payment target (classes and students).
//
// Extracted from admin_finance_screen.dart to reduce file size.
// Allows the admin to pick which classes/students a payment type targets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/selection_logic_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/ui_builder_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/student_ui_builder_mixin.dart';

/// A bottom sheet that lets the admin select target classes and students
/// for a payment type.
///
/// Receives class/student data from the parent, and calls [onSave] with
/// the built goal data when the user confirms.
class TargetSelectionModal extends StatefulWidget {
  final Map<String, dynamic>? paymentType;
  final Function(Map<String, dynamic>) onSave;
  final Color primaryColor;
  final List<dynamic> classList;
  final Map<String, List<dynamic>> studentsByClass;

  const TargetSelectionModal({
    super.key,
    this.paymentType,
    required this.onSave,
    required this.primaryColor,
    required this.classList,
    required this.studentsByClass,
  });

  @override
  State<TargetSelectionModal> createState() => _TargetSelectionModalState();
}

class _TargetSelectionModalState extends State<TargetSelectionModal>
    with SelectionLogicMixin, UiBuilderMixin, StudentUiBuilderMixin {
  List<dynamic> _selectedClasses = [];
  final Map<String, List<dynamic>> _selectedStudentsByClass = {};
  final TextEditingController _searchStudentController =
      TextEditingController();

  @override
  List<dynamic> get selectedClasses => _selectedClasses;

  @override
  Map<String, List<dynamic>> get selectedStudentsByClass =>
      _selectedStudentsByClass;

  @override
  TextEditingController get searchStudentController => _searchStudentController;

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  LanguageProvider get languageProvider => LanguageProvider();

  @override
  void initState() {
    super.initState();
    if (widget.paymentType?['goal'] != null) {
      loadExistingGoal(widget.paymentType!['goal']);
    }
  }

  @override
  void dispose() {
    _searchStudentController.dispose();
    super.dispose();
  }

  void selectAllClasses() {
    setState(() {
      _selectedClasses = List.from(widget.classList);
      for (final classItem in widget.classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          widget.studentsByClass[classId] ?? [],
        );
      }
    });
  }

  void clearAllSelection() {
    setState(() {
      _selectedClasses.clear();
      _selectedStudentsByClass.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildSearchField(),
          _buildQuickActions(),
          Expanded(child: buildClassListForSelection()),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: Colors.white, size: 24),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Pilih Tujuan Pembayaran',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => AppNavigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: TextField(
          controller: _searchStudentController,
          decoration: InputDecoration(
            hintText: 'Cari siswa...',
            prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildSelectAllButton()),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildClearAllButton()),
        ],
      ),
    );
  }

  Widget _buildSelectAllButton() {
    return OutlinedButton(
      onPressed: selectAllClasses,
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        side: BorderSide(color: primaryColor),
      ),
      child: Text(
        'Pilih Semua Kelas',
        style: TextStyle(fontSize: 12, color: primaryColor),
      ),
    );
  }

  Widget _buildClearAllButton() {
    return OutlinedButton(
      onPressed: clearAllSelection,
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        side: BorderSide(color: ColorUtils.error600),
      ),
      child: Text(
        'Hapus Semua',
        style: TextStyle(fontSize: 12, color: ColorUtils.error600),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(
        children: [
          buildSelectionSummary(),
          const SizedBox(height: AppSpacing.md),
          _buildFooterButtons(context),
        ],
      ),
    );
  }

  Widget _buildFooterButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildCancelButton(context)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildSaveButton(context)),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => AppNavigator.pop(context),
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(AppLocalizations.cancel.tr),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final goal = buildGoalData();
        widget.onSave(goal);
        AppNavigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        AppLocalizations.save.tr,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
