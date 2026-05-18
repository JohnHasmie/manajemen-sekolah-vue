// Phase-4 Profile Page matching mockup surface 1.
//
// Compact 180px gradient hero with big avatar overlapping the bottom.
// Two cards: "Informasi Pribadi" (email, phone, address) and
// "Akun & Akses" (peran, sekolah). Logout button at the bottom.
//
// Opened from: Account Sheet → "Lihat Profil Lengkap"
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_profile_components.dart';
import 'package:manajemensekolah/features/account/data/profile_service.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/change_password_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic> _userData = {};
  String _role = 'wali';
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final raw = PreferencesService().getString('user');
    if (raw != null) {
      _userData = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    final dashState = ref.read(dashboardProvider).asData?.value;
    if (dashState != null) {
      _userData = {..._userData, ...dashState.userData};
      _role = (dashState.userData['role'] ?? _role).toString();
    }
    if (mounted) setState(() {});
  }

  String get _name =>
      (_userData['name'] ?? _userData['nama'] ?? 'Pengguna').toString();
  String get _email => (_userData['email'] ?? '-').toString();
  String get _phone =>
      (_userData['phone'] ?? _userData['no_telepon'] ?? '-').toString();
  String get _address =>
      (_userData['address'] ?? _userData['alamat'] ?? '-').toString();
  String get _schoolName =>
      (_userData['school_name'] ?? _userData['nama_sekolah'] ?? '-').toString();
  String get _roleLabel {
    return switch (_role) {
      'admin' => 'Admin',
      'guru' => 'Guru',
      'wali' => 'Wali Murid',
      _ => _role,
    };
  }

  String get _initial {
    final n = _name.trim();
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }

  Color get _accentColor => ColorUtils.getRoleColor(_role);

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await TokenService().logout();
      if (!mounted) return;
      AppNavigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      SnackBarUtils.showError(context, 'Gagal keluar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero gradient 180px
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: ColorUtils.brandGradient(_role),
                ),
                padding: EdgeInsets.only(top: statusBarHeight),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _HeroButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => AppNavigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'Profil Saya',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Edit pencil
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _HeroButton(
                        icon: Icons.edit_outlined,
                        onTap: () {
                          // TODO: inline edit mode
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Big avatar overlapping hero bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: -50,
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accentColor.withValues(alpha: 0.14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initial,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: _accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          // Name + email + role pill
          Center(
            child: Column(
              children: [
                Text(
                  _name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _roleLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Card 1: Informasi Pribadi
          _buildInfoCard(),
          const SizedBox(height: 12),
          // Card 2: Akun & Akses
          _buildAccessCard(),
          const SizedBox(height: 12),
          // Card 3: SecurityChecklistCard (Mockup #15 — admin only).
          // Shown for admin role; other roles can opt-in later by
          // dropping the gate.
          if (_role == 'admin') _buildSecurityCard(),
          const SizedBox(height: 24),
          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isLoggingOut ? null : _logout,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: _isLoggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Keluar Akun',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                'Informasi Pribadi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Tap pensil di kanan atas untuk edit',
                style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Color(0xFFF1F5F9), height: 20),
            ),
            _InfoRow(label: 'EMAIL', value: _email),
            _InfoRow(
              label: 'NO. TELEPON',
              value: _phone,
              trailing: _phone != '-'
                  ? null
                  : Text(
                      'Verif',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _accentColor,
                      ),
                    ),
            ),
            _InfoRow(label: 'ALAMAT', value: _address),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Mockup #15 — Security checklist card. Watches the
  /// [securityStatusProvider] and renders the shared
  /// [SecurityChecklistCard] from `lib/core/widgets/`. While the
  /// request is in-flight or errored, falls back to a neutral
  /// placeholder so the screen never blocks.
  Widget _buildSecurityCard() {
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(securityStatusProvider);
        return async.when(
          data: (result) => SecurityChecklistCard(
            items: result.toChecks((route) {
              // Routes are owned by the Flutter side — map them to
              // existing screens. Today only "change-password" is wired;
              // 2FA + verify-email TBD.
              if (route.endsWith('/change-password')) {
                showDialog(
                  context: context,
                  builder: (_) =>
                      ChangePasswordDialog(primaryColor: _accentColor),
                );
              } else {
                SnackBarUtils.showError(context, 'Aksi belum tersedia: $route');
              }
            }),
          ),
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildAccessCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                'Akun & Akses',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Color(0xFFF1F5F9), height: 20),
            ),
            _AccessRow(
              icon: Icons.person_outline,
              iconColor: _accentColor,
              label: 'Peran aktif',
              value: _roleLabel,
              actionLabel: 'Ganti',
              onTap: () {
                // TODO: role switch
              },
            ),
            const SizedBox(height: 8),
            _AccessRow(
              icon: Icons.school_outlined,
              iconColor: ColorUtils.success600,
              label: 'Sekolah aktif',
              value: _schoolName,
              actionLabel: 'Ganti',
              onTap: () {
                // TODO: school switch
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback onTap;

  const _AccessRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
