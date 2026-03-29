// User profile/settings screen - displays user profile info and app settings.
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/settings.vue` or `pages/profile.vue` - shared across all roles
// (admin, guru, wali). Shows user profile data, language selection, and
// app configuration options.
//
// In Laravel terms, this calls `GET /api/profile` to fetch user details.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/change_password_dialog.dart';

/// User profile and settings screen - shared across all roles.
///
/// This is a [StatefulWidget] with local state for profile data and role-based theming.
/// Uses cache-first pattern for instant profile display.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState createState() => _SettingsScreenState();
}

/// Mutable state for [SettingsScreen].
///
/// Key state (like Vue `data()`):
/// - [_profileData] - user profile from API (name, email, school, etc.)
/// - [_role] - current user role for theming (determines primary color)
/// - [_isLoading] - loading state for skeleton display
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};
  String _role = 'admin';

  Color get _primaryColor => ColorUtils.getRoleColor(_role);

  /// Like Vue's `mounted()` - loads the user's role from SharedPreferences
  /// and fetches profile data with cache-first pattern.
  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadProfile();
  }

  Future<void> _loadRole() async {
    try {
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = jsonDecode(userJson);
        final rawRole = user['role']?.toString() ?? 'admin';
        // Normalize role aliases
        String normalizedRole = rawRole;
        if (rawRole == 'teacher') normalizedRole = 'guru';
        if (rawRole == 'parent') normalizedRole = 'wali';
        if (mounted) setState(() => _role = normalizedRole);
      }
    } catch (e) {
      AppLogger.error('settings', e);
    }
  }

  static const String _profileCacheKey = 'settings_profile';

  Future<void> _forceRefresh() async {
    await LocalCacheService.invalidate(_profileCacheKey);
    _loadProfile(useCache: false);
  }

  /// Loads user profile with cache-first pattern.
  /// Like calling `GET /api/profile` in Vue with localStorage fallback for instant display.
  Future<void> _loadProfile({bool useCache = true}) async {
    // Step 1: Try cache for instant display
    if (useCache) {
      final cached = await LocalCacheService.load(_profileCacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _profileData = cached;
          _isLoading = false;
        });
      }
    }

    // Step 2: Show loading only if no data yet
    if (_profileData.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 3: Fetch fresh from API
    try {
      final data = await getIt<ApiSettingsService>().getProfile();
      if (!mounted) return;

      await LocalCacheService.save(_profileCacheKey, data);

      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('settings', e);
      if (!mounted) return;
      // Only show error if no cached data
      if (_profileData.isEmpty) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(
          context,
          '${ref.read(languageRiverpod).getTranslatedText(AppLocalizations.failedToLoadProfile)}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _profileData['name']);
    final phoneController = TextEditingController(
      text: _profileData['phone_number'],
    );
    final addressController = TextEditingController(
      text: _profileData['address'],
    );

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      _primaryColor,
                      _primaryColor.withValues(alpha: 0.85),
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
                        Icons.person_rounded,
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
                            ref
                                .read(languageRiverpod)
                                .getTranslatedText(
                                  AppLocalizations.editProfile,
                                ),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Perbarui informasi profil Anda',
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
                    _buildDialogTextField(
                      controller: nameController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.fullName),
                      icon: Icons.person_outline_rounded,
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogTextField(
                      controller: phoneController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.phoneNumber),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogTextField(
                      controller: addressController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.address),
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
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
                            ref
                                .read(languageRiverpod)
                                .getTranslatedText(AppLocalizations.cancel),
                            style: TextStyle(color: ColorUtils.slate600),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final lang = ref.read(languageRiverpod);
                            try {
                              await getIt<ApiSettingsService>().updateProfile(
                                name: nameController.text,
                                phoneNumber: phoneController.text,
                                address: addressController.text,
                              );
                              await LocalCacheService.invalidate(
                                _profileCacheKey,
                              );
                              if (mounted) {
                                AppNavigator.pop(context);
                                _loadProfile(useCache: false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang.getTranslatedText(
                                        AppLocalizations.profileUpdatedSuccess,
                                      ),
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
                                      '${lang.getTranslatedText(AppLocalizations.failedToUpdateProfile)}: ${ErrorUtils.getFriendlyMessage(e)}',
                                    ),
                                    backgroundColor: ColorUtils.error600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            ref
                                .read(languageRiverpod)
                                .getTranslatedText(AppLocalizations.save),
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
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(primaryColor: _primaryColor),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor, size: 20),
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
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryColor, size: 18),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : '-',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData sectionIcon,
    required String sectionTitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(sectionIcon, color: _primaryColor, size: 17),
                ),
                SizedBox(width: 10),
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Divider(color: ColorUtils.slate100, height: 1),
            SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _profileData['name'] ?? '';
    final role =
        (_profileData['role'] != null &&
            (_profileData['role'] as String).isNotEmpty)
        ? (_profileData['role'] as String)[0].toUpperCase() +
              (_profileData['role'] as String).substring(1)
        : 'Admin';
    final email = _profileData['email'] ?? '';
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: _isLoading
          ? const SkeletonListLoading()
          : CustomScrollView(
              slivers: [
                // Gradient SliverAppBar with profile hero (Pattern #7)
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: _primaryColor,
                  iconTheme: IconThemeData(color: Colors.white),
                  title: Text(
                    ref
                        .watch(languageRiverpod)
                        .getTranslatedText(AppLocalizations.userProfile),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: _showEditProfileDialog,
                      tooltip: 'Edit Profil',
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'refresh') _forceRefresh();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 20,
                                color: ColorUtils.info600,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(AppLocalizations.updateData.tr),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: AppSpacing.sm),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primaryColor,
                            _primaryColor.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 56, 20, 20),
                          child: Row(
                            children: [
                              // Avatar with initials
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    avatarLetter,
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isNotEmpty ? name : 'Pengguna',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        // Personal Information Card
                        _buildSectionCard(
                          sectionIcon: Icons.person_outline_rounded,
                          sectionTitle: ref
                              .read(languageRiverpod)
                              .getTranslatedText(
                                AppLocalizations.personalInformation,
                              ),
                          children: [
                            _buildInfoRow(
                              ref
                                  .read(languageRiverpod)
                                  .getTranslatedText(AppLocalizations.fullName),
                              _profileData['name'] ?? '',
                              Icons.person_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoRow(
                              'Email',
                              _profileData['email'] ?? '',
                              Icons.email_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoRow(
                              'No. Telepon',
                              _profileData['phone_number'] ?? '',
                              Icons.phone_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoRow(
                              'Alamat',
                              _profileData['address'] ?? '',
                              Icons.location_on_rounded,
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.md),

                        // Account Information Card
                        _buildSectionCard(
                          sectionIcon: Icons.manage_accounts_rounded,
                          sectionTitle: ref
                              .read(languageRiverpod)
                              .getTranslatedText(
                                AppLocalizations.accountInformation,
                              ),
                          children: [
                            _buildInfoRow(
                              ref
                                  .read(languageRiverpod)
                                  .getTranslatedText(AppLocalizations.role),
                              role,
                              Icons.badge_rounded,
                            ),
                            SizedBox(height: AppSpacing.md),
                            _buildInfoRow(
                              ref
                                  .read(languageRiverpod)
                                  .getTranslatedText(AppLocalizations.school),
                              _profileData['school_name'] ?? '',
                              Icons.school_rounded,
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xxl),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _showChangePasswordDialog,
                            icon: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              ref
                                  .watch(languageRiverpod)
                                  .getTranslatedText(
                                    AppLocalizations.changePassword,
                                  ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
