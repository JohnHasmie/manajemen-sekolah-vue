// School level (jenjang) settings screen - configure school name,
// address, and level.
//
// Like `pages/admin/settings/school-info.vue` - a simple settings form
// for editing the school's basic information (name, address, education
// level: SD/SMP/SMA/SMK).
//
// In Laravel terms, this calls `GET /api/settings/school` and
// `PUT /api/settings/school`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_data_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_dialog_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_dialog_builder_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_ui_builders_mixin.dart';

/// School info settings screen - edit school name, address, and
/// education level (jenjang).
///
/// This is a [StatefulWidget] - like a Vue form page with local state
/// for form fields.
class SchoolLevelSettingsScreen extends StatefulWidget {
  const SchoolLevelSettingsScreen({super.key});

  @override
  State<SchoolLevelSettingsScreen> createState() =>
      _SchoolLevelSettingsScreenState();
}

/// Mutable state for [SchoolLevelSettingsScreen].
///
/// Key state (like Vue `data()`):
/// - [_schoolName] / [_schoolAddress] / [_selectedJenjang] - form values
/// - [_isLoading] - loading indicator state
///
/// setState() triggers re-render like Vue's reactivity system.
class _SchoolLevelSettingsScreenState extends State<SchoolLevelSettingsScreen>
    with
        SchoolLevelDataMixin,
        SchoolLevelDialogMixin,
        SchoolLevelDialogBuilderMixin,
        SchoolLevelUIBuildersMixin {
  String _schoolName = '';
  String _schoolAddress = '';
  String _selectedJenjang = 'SMA';
  final List<String> _jenjangOptions = ['SD', 'SMP', 'SMA', 'SMK'];
  bool _isLoading = true;

  /// Like Vue's `mounted()` - loads current school settings from API.
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Internal wrapper for _loadSettings to use mixin's API method.
  void _loadSettings() {
    loadSchoolSettings(
      onSchoolNameChanged: (name) => _schoolName = name,
      onAddressChanged: (addr) => _schoolAddress = addr,
      onJenjangChanged: (level) => _selectedJenjang = level,
      onLoadingChanged: (loading) => _isLoading = loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _isLoading
                  ? const SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the custom gradient header.
  Widget _buildHeader() {
    return Container(
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
            offset: const Offset(0, 2),
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
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan Umum',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
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
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the main body content.
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async => _loadSettings(),
      color: ColorUtils.corporateBlue600,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: ColorUtils.corporateBlue600,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
            buildInfoCard('Nama Sekolah', _schoolName, Icons.school_rounded),
            const SizedBox(height: AppSpacing.md),
            buildInfoCard(
              'Alamat Sekolah',
              _schoolAddress,
              Icons.location_on_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            buildInfoCard(
              'Jenjang Pendidikan',
              _selectedJenjang,
              Icons.stairs_rounded,
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the edit dialog.
  Future<void> _showEditDialog() async {
    await showEditDialog(
      schoolName: _schoolName,
      schoolAddress: _schoolAddress,
      selectedJenjang: _selectedJenjang,
      jenjangOptions: _jenjangOptions,
      onLoadSettings: _loadSettings,
      onSaveSettings: (name, addr, level) async {
        await updateSchoolSettings(
          schoolName: name,
          address: addr,
          jenjang: level,
        );
      },
    );
  }
}
