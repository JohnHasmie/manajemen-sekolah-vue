// User profile/settings screen - displays user profile
// info and app settings.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_profile_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_dialogs_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_ui_builders_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_appbar_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_cards_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/settings_screen_textfield_mixin.dart';

/// User profile and settings screen - shared across all
/// roles. Uses cache-first pattern for instant display.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState createState() => _SettingsScreenState();
}

/// Mutable state for [SettingsScreen].
///
/// Key state:
/// - [_profileData] - user profile from API
/// - [_role] - current user role for theming
/// - [_isLoading] - loading state for skeleton
class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with
        SettingsScreenProfileMixin,
        SettingsScreenDialogsMixin,
        SettingsScreenUIBuildersMixin,
        SettingsScreenAppBarMixin,
        SettingsScreenCardsMixin,
        SettingsScreenTextFieldMixin {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};
  String _role = 'admin';

  Color get _primaryColor => ColorUtils.getRoleColor(_role);

  // Implement abstract properties for mixins
  @override
  Map<String, dynamic> get profileData => _profileData;
  @override
  set profileData(Map<String, dynamic> value) => _profileData = value;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;
  @override
  String get role => _role;
  @override
  set role(String value) => _role = value;
  @override
  Color get primaryColor => _primaryColor;

  @override
  void initState() {
    super.initState();
    loadRole();
    loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final name = _profileData['name'] ?? '';
    final role = _formatRole(_profileData['role']);
    final email = _profileData['email'] ?? '';
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: _isLoading
          ? const SkeletonListLoading()
          : CustomScrollView(
              slivers: [
                buildSliverAppBar(
                  name,
                  email,
                  role,
                  avatarLetter,
                  // Wrapped instead of passing the bare tear-off so
                  // the Future<void> result of the dialog future is
                  // explicitly fire-and-forget — passing the bare
                  // reference to a VoidCallback slot was producing
                  // an unhandled-future runtime swallow that left
                  // the pencil tap looking like a no-op.
                  // ignore: unnecessary_lambdas
                  () => showEditProfileDialog(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        buildPersonalInfoCard(),
                        const SizedBox(height: AppSpacing.md),
                        buildAccountInfoCard(role),
                        const SizedBox(height: AppSpacing.lg),
                        // Change password kept as a secondary action;
                        // primary "Keluar Akun" button takes the
                        // brand-recommended danger spot at the
                        // bottom of the page.
                        buildChangePasswordButton(showChangePasswordDialog),
                        const SizedBox(height: AppSpacing.md),
                        buildLogoutButton(context),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Formats role string for display.
  String _formatRole(dynamic roleData) {
    if (roleData != null && (roleData as String).isNotEmpty) {
      final role = roleData;
      return role[0].toUpperCase() + role.substring(1);
    }
    return 'Admin';
  }
}
