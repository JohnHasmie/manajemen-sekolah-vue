import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// UI builder mixin for GenerateBillsDialog, handling all presentation logic.
mixin GenerateBillsDialogUiMixin {
  // Required from State.
  void setState(VoidCallback fn);
  BuildContext get context;
  // Abstract properties that must be implemented by the state class.
  Color get primaryColor;
  LinearGradient get cardGradient;
  Map<String, dynamic> get paymentType;

  String get selectedMonth;
  set selectedMonth(String value);

  String? get selectedAcademicYearId;
  set selectedAcademicYearId(String? value);

  List<dynamic> get academicYears;
  set academicYears(List<dynamic> value);

  List<String> get generatedMonths;
  set generatedMonths(List<String> value);

  bool get isLoadingYears;
  set isLoadingYears(bool value);

  bool get isLoadingGenerated;
  set isLoadingGenerated(bool value);

  static const List<String> months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Builds the gradient header with icon and
  /// payment type name.
  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(gradient: cardGradient),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: 14),
          Expanded(child: _buildHeaderText()),
        ],
      ),
    );
  }

  /// Builds the header icon container with rounded white background.
  Widget _buildHeaderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  /// Builds header text with title and payment type.
  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate Tagihan',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          paymentType['name'] ?? '',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Builds main content area with academic year dropdown and month grid.
  Widget buildContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionLabel(Icons.school_rounded, 'Tahun Ajaran'),
          const SizedBox(height: 10),
          buildAcademicYearDropdown(),
          const SizedBox(height: AppSpacing.xl),
          buildSectionLabel(Icons.date_range_rounded, 'Pilih Bulan'),
          const SizedBox(height: 10),
          buildMonthGrid(),
        ],
      ),
    );
  }

  /// Builds a section label with icon and text.
  Widget buildSectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: ColorUtils.slate600),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate800,
          ),
        ),
      ],
    );
  }

  /// Builds academic year dropdown with loading state.
  Widget buildAcademicYearDropdown() {
    if (isLoadingYears) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: selectedAcademicYearId,
          decoration: _buildDropdownDecoration(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate900,
            fontSize: 14,
          ),
          items: _buildDropdownItems(),
          onChanged: _onAcademicYearChanged,
        ),
      ),
    );
  }

  /// Builds dropdown input decoration.
  InputDecoration _buildDropdownDecoration() {
    return InputDecoration(
      prefixIcon: Icon(
        Icons.calendar_today_rounded,
        color: primaryColor,
        size: 18,
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  /// Builds dropdown menu items.
  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return academicYears.map((y) {
      return DropdownMenuItem<String>(
        value: y['id'].toString(),
        child: Text(y['year'] ?? 'Unknown'),
      );
    }).toList();
  }

  /// Builds month selection grid with generated month indicators.
  Widget buildMonthGrid() {
    if (isLoadingGenerated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: months.length,
      itemBuilder: (context, index) => _buildMonthTile(months[index]),
    );
  }

  /// Builds single month tile with state-based styling.
  Widget _buildMonthTile(String month) {
    final isGenerated = generatedMonths.contains(month);
    final isSelected = selectedMonth == month;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGenerated ? null : () => setState(() => selectedMonth = month),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          alignment: Alignment.center,
          decoration: _buildMonthTileDecoration(isGenerated, isSelected),
          child: Stack(
            children: [
              Center(child: _buildMonthText(month, isGenerated, isSelected)),
              if (isGenerated)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: ColorUtils.success600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds month tile decoration based on state.
  BoxDecoration _buildMonthTileDecoration(bool isGenerated, bool isSelected) {
    return BoxDecoration(
      color: isGenerated
          ? ColorUtils.slate100
          : isSelected
          ? primaryColor
          : Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      border: Border.all(
        color: isGenerated
            ? ColorUtils.slate200
            : isSelected
            ? primaryColor
            : ColorUtils.slate200,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Builds text widget for month tile.
  Text _buildMonthText(String month, bool isGenerated, bool isSelected) {
    return Text(
      month,
      style: TextStyle(
        color: isGenerated
            ? ColorUtils.slate400
            : isSelected
            ? Colors.white
            : ColorUtils.slate700,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  /// Builds footer with Cancel and Generate buttons.
  Widget buildFooter(bool canGenerate, VoidCallback onGenerate) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(child: _buildCancelButton()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildGenerateButton(canGenerate, onGenerate)),
        ],
      ),
    );
  }

  /// Builds Cancel button.
  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: ColorUtils.slate300),
      ),
      child: Text(
        AppLocalizations.cancel.tr,
        style: TextStyle(color: ColorUtils.slate600),
      ),
    );
  }

  /// Builds Generate button.
  Widget _buildGenerateButton(bool canGenerate, VoidCallback onGenerate) {
    return ElevatedButton.icon(
      onPressed: canGenerate ? onGenerate : null,
      icon: const Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: Colors.white,
      ),
      label: const Text(
        'Generate',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        disabledBackgroundColor: ColorUtils.slate300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        elevation: 0,
      ),
    );
  }

  /// Handles academic year dropdown change.
  void _onAcademicYearChanged(String? val) {
    if (val != null) {
      setState(() {
        selectedAcademicYearId = val;
        isLoadingGenerated = true;
        generatedMonths = [];
      });
      _notifyAcademicYearChanged(val);
    }
  }

  /// Callback for state to handle academic year changes.
  void _notifyAcademicYearChanged(String academicYearId);
}
