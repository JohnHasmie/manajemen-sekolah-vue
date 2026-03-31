// Dialog for selecting a month and academic year, then generating bills
// for a given payment type.
//
// Extracted from `_confirmGenerateBills` in admin_finance_screen.dart.
// Like a Vue `<GenerateBillsDialog :paymentType="pt" @generated="reload" />`
// component — it fetches academic years itself, lets the admin pick a month,
// then pops with the chosen params so the parent can call the generate API.
//
// The parent is responsible for calling FinanceService.generateBills() after
// the dialog resolves (via [onGenerated] callback), so no service call lives
// inside this widget.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';

/// Full-screen dialog for generating bills for a payment type.
///
/// Shows a month grid (with already-generated months disabled) and an
/// academic-year dropdown.  On confirm, calls [onGenerated] so the parent
/// can reload its data.
///
/// In Vue terms: `<GenerateBillsDialog :paymentType="pt" @generated="reload" />`
class GenerateBillsDialog extends StatefulWidget {
  /// The payment-type map from the API (needs at minimum `id` and `name`).
  final Map<String, dynamic> paymentType;

  /// Primary theme colour already resolved by the parent (`_getPrimaryColor()`).
  final Color primaryColor;

  /// Gradient used for the dialog header — same as `_getCardGradient()`.
  final LinearGradient cardGradient;

  /// Called after the generate-bills API call succeeds, so the parent can
  /// refresh its list (equivalent to `_loadData(useCache: false)`).
  final VoidCallback onGenerated;

  const GenerateBillsDialog({
    super.key,
    required this.paymentType,
    required this.primaryColor,
    required this.cardGradient,
    required this.onGenerated,
  });

  @override
  State<GenerateBillsDialog> createState() => _GenerateBillsDialogState();
}

class _GenerateBillsDialogState extends State<GenerateBillsDialog> {
  // Currently selected month name (Indonesian), defaults to current month.
  String _selectedMonth = DateFormat('MMMM', 'id_ID').format(DateTime.now());
  String? _selectedAcademicYearId;

  List<dynamic> _academicYears = [];
  List<String> _generatedMonths = [];

  bool _isLoadingYears = true;
  bool _isLoadingGenerated = false;

  // Fixed list of Indonesian month names (Jan–Dec).
  static const List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAcademicYears();
  }

  // ─── Data fetching ───────────────────────────────────────────────────────────

  Future<void> _fetchAcademicYears() async {
    try {
      final years = await getIt<ApiAcademicServices>().getAcademicYears();
      if (!mounted) return;

      final activeYear = years.firstWhere(
        (y) => y['current'] == true || y['status'] == 'active',
        orElse: () => years.isNotEmpty ? years.first : null,
      );

      setState(() {
        _academicYears = years;
        _isLoadingYears = false;
        if (activeYear != null) {
          _selectedAcademicYearId = activeYear['id'].toString();
          _isLoadingGenerated = true;
        }
      });

      if (_selectedAcademicYearId != null) {
        await _fetchGeneratedMonths(_selectedAcademicYearId!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingYears = false);
    }
  }

  Future<void> _fetchGeneratedMonths(String academicYearId) async {
    try {
      final genMonths = await FinanceService.getGeneratedMonths(
        paymentTypeId: widget.paymentType['id'].toString(),
        academicYearId: academicYearId,
      );
      if (mounted) {
        setState(() {
          _generatedMonths = genMonths;
          _isLoadingGenerated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGenerated = false);
    }
  }

  // ─── Generate action (called when user taps the Generate button) ─────────────

  Future<void> _generate() async {
    if (_selectedAcademicYearId == null) return;
    AppNavigator.pop(context); // close the dialog first

    try {
      final response = await FinanceService.generateBills(
        paymentTypeId: widget.paymentType['id'].toString(),
        month: _selectedMonth,
        academicYearId: _selectedAcademicYearId!,
      );

      if (mounted) {
        String message = 'Tagihan berhasil dibuat';
        if (response != null && response['message'] != null) {
          message = response['message'];
        }
        if (response != null &&
            response['errors'] != null &&
            (response['errors'] as List).isNotEmpty) {
          message = (response['errors'] as List).join('\n');
        }
        SnackBarUtils.showSuccess(context, message);
      }

      widget.onGenerated();
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToGenerate.tr}: ${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        _selectedAcademicYearId != null &&
        !_generatedMonths.contains(_selectedMonth);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20))),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildFooter(canGenerate),
          ],
        ),
      ),
    );
  }

  // Gradient header with icon + payment type name.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(gradient: widget.cardGradient),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Tagihan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.paymentType['name'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Academic year dropdown + month grid.
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(Icons.school_rounded, 'Tahun Ajaran'),
          const SizedBox(height: 10),
          _buildAcademicYearDropdown(),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionLabel(Icons.date_range_rounded, 'Pilih Bulan'),
          const SizedBox(height: 10),
          _buildMonthGrid(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String text) {
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

  Widget _buildAcademicYearDropdown() {
    if (_isLoadingYears) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(color: widget.primaryColor),
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
          initialValue: _selectedAcademicYearId,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.calendar_today_rounded,
              color: widget.primaryColor,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate900,
            fontSize: 14,
          ),
          items: _academicYears.map((y) {
            return DropdownMenuItem<String>(
              value: y['id'].toString(),
              child: Text(y['year'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedAcademicYearId = val;
                _isLoadingGenerated = true;
                _generatedMonths = [];
              });
              _fetchGeneratedMonths(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    if (_isLoadingGenerated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(color: widget.primaryColor),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        final month = _months[index];
        final isGenerated = _generatedMonths.contains(month);
        final isSelected = _selectedMonth == month;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isGenerated
                ? null
                : () => setState(() => _selectedMonth = month),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isGenerated
                    ? ColorUtils.slate100
                    : isSelected
                    ? widget.primaryColor
                    : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(
                  color: isGenerated
                      ? ColorUtils.slate200
                      : isSelected
                      ? widget.primaryColor
                      : ColorUtils.slate200,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      month,
                      style: TextStyle(
                        color: isGenerated
                            ? ColorUtils.slate400
                            : isSelected
                            ? Colors.white
                            : ColorUtils.slate700,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
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
      },
    );
  }

  // Cancel / Generate buttons.
  Widget _buildFooter(bool canGenerate) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: ColorUtils.slate300),
              ),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate600),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canGenerate ? _generate : null,
              icon: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
              label: Text(
                'Generate',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                disabledBackgroundColor: ColorUtils.slate300,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
