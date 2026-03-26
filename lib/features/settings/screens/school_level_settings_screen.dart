// School level (jenjang) settings screen - configure school name, address, and level.
//
// Like `pages/admin/settings/school-info.vue` - a simple settings form for
// editing the school's basic information (name, address, education level: SD/SMP/SMA/SMK).
//
// In Laravel terms, this calls `GET /api/settings/school` and `PUT /api/settings/school`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/settings/services/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// School info settings screen - edit school name, address, and education level (jenjang).
///
/// This is a [StatefulWidget] - like a Vue form page with local state for form fields.
class SchoolLevelSettingsScreen extends StatefulWidget {
  const SchoolLevelSettingsScreen({super.key});

  @override
  State<SchoolLevelSettingsScreen> createState() =>
      _SchoolLevelSettingsScreenState();
}

/// Mutable state for [SchoolLevelSettingsScreen].
///
/// Key state (like Vue `data()`):
/// - [_schoolName] / [_schoolAddress] / [_selectedJenjang] - form field values
/// - [_isLoading] - loading indicator state
///
/// setState() triggers re-render like Vue's reactivity system.
class _SchoolLevelSettingsScreenState extends State<SchoolLevelSettingsScreen> {
  String _schoolName = '';
  String _schoolAddress = '';
  String _selectedJenjang = 'SMA';
  final List<String> _jenjangOptions = ['SD', 'SMP', 'SMA', 'SMK'];
  bool _isLoading = true;

  /// Like Vue's `mounted()` - loads current school settings from the API.
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Fetches school settings from API. Like calling `GET /api/settings/school` in Vue.
  Future<void> _loadSettings() async {
    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      setState(() {
        _schoolName = settings['school_name'] ?? '';
        _schoolAddress = settings['address'] ?? '';
        _selectedJenjang = settings['jenjang'] ?? 'SMA';
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
        setState(() => _isLoading = false);
                SnackBarUtils.showError(context, 'Gagal memuat pengaturan: ${ErrorUtils.getFriendlyMessage(e)}');
      }
    }
  }

  /// Shows a dialog to edit school info. Like a Vue `<v-dialog>` with form fields.
  /// Uses `StatefulBuilder` inside the dialog - this is like having a nested Vue component
  /// with its own local state inside a modal.
  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _schoolName);
    final addressController = TextEditingController(text: _schoolAddress);
    String tempJenjang = _selectedJenjang;

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header (Pattern #10)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue600,
                        ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Informasi Sekolah',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Perbarui data informasi sekolah',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        label: 'Nama Sekolah',
                        icon: Icons.school_outlined,
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildStyledTextField(
                        controller: addressController,
                        label: 'Alamat Sekolah',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: tempJenjang,
                        decoration: InputDecoration(
                          labelText: 'Jenjang Sekolah',
                          prefixIcon: Icon(
                            Icons.stairs_rounded,
                            color: ColorUtils.corporateBlue600,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: ColorUtils.corporateBlue600,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: ColorUtils.slate50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        items: _jenjangOptions
                            .map(
                              (j) => DropdownMenuItem(value: j, child: Text(j)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => tempJenjang = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Footer
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate100)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.cancel.tr,
                              style: TextStyle(color: ColorUtils.slate600),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              final name = nameController.text.trim();
                              if (name.length < 3) {
                                                                SnackBarUtils.showError(context, AppLocalizations.schoolNameMinChars.tr);
                                return;
                              }

                              setDialogState(() => isSaving = true);

                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await getIt<ApiSettingsService>().updateSchoolSettings(
                                  schoolName: name,
                                  address: addressController.text.trim(),
                                  jenjang: tempJenjang,
                                );
                                if (mounted) {
                                  AppNavigator.pop(context);
                                  _loadSettings();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.settingsSavedSuccess.tr,
                                      ),
                                      backgroundColor: ColorUtils.success600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                AppLogger.error('settings', e);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
                                      ),
                                      backgroundColor: ColorUtils.error600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setDialogState(() => isSaving = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              disabledBackgroundColor: ColorUtils.corporateBlue600.withValues(alpha: 0.6),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                              AppLocalizations.save.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ColorUtils.corporateBlue600,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: ColorUtils.corporateBlue600, size: 22),
          ),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Custom Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan Umum',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Jenjang & informasi sekolah',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading)
                  GestureDetector(
                    onTap: _showEditDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _isLoading
                  ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : RefreshIndicator(
                      onRefresh: _loadSettings,
                      color: ColorUtils.corporateBlue600,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: ColorUtils.corporateBlue600
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: ColorUtils.corporateBlue600,
                                      size: 17,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Informasi Sekolah',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: ColorUtils.slate800,
                                        ),
                                      ),
                                      Text(
                                        'Kelola informasi dasar sekolah Anda.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ColorUtils.slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _buildInfoCard(
                              'Nama Sekolah',
                              _schoolName,
                              Icons.school_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoCard(
                              'Alamat Sekolah',
                              _schoolAddress,
                              Icons.location_on_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoCard(
                              'Jenjang Pendidikan',
                              _selectedJenjang,
                              Icons.stairs_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
