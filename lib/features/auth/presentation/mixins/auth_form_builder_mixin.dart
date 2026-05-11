// Renders the picker steps (school / role / otp) inside the login
// screen's form-card. Frames D and E of
// `_design/auth_login_school_role_redesign.html` set the expected
// chrome:
//   • greeting / school kicker + title + subtitle + step dots header
//   • School: search bar, UTAMA + SEKOLAH LAIN sections, gradient
//     logo cards with role pill row, sticky "Lanjutkan ke …" footer
//   • Role: accent-bar cards in role color (admin navy / guru cobalt /
//     wali azure), role icon + description + stats row, sticky CTA
//
// Both pickers track a *candidate* selection locally (UTAMA highlight
// + cobalt CTA) and only fire the network call on the Lanjutkan tap,
// matching the mockup's two-step pattern.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';

mixin AuthFormBuilderMixin on ConsumerState<LoginScreen> {
  Widget buildCurrentAuthStep(AuthState authState) {
    switch (authState.step) {
      case AuthStep.schoolSelection:
        return _SchoolPickerStep(
          authState: authState,
          onConfirm: (schoolId) =>
              ref.read(authProvider.notifier).selectSchool(schoolId),
          onBackToLogin: () => ref.read(authProvider.notifier).resetToLogin(),
        );
      case AuthStep.roleSelection:
        return _RolePickerStep(
          authState: authState,
          getRoleDisplayName: getRoleDisplayName,
          getRoleDescription: getRoleDescription,
          getRoleColor: _roleColor,
          getRoleIconData: _roleIconData,
          getRoleStats: _roleStatsFor,
          onConfirm: (role) => ref.read(authProvider.notifier).selectRole(role),
          onBackToLogin: () => ref.read(authProvider.notifier).resetToLogin(),
        );
      case AuthStep.otpVerification:
        return buildOtpForm(authState);
      case AuthStep.login:
        return buildLoginForm(authState);
    }
  }

  // ─── Role color / icon / stats helpers ──────────────────────────
  // The role accent (Frame E) follows the same admin-navy / guru-
  // cobalt / wali-azure palette the rest of the app already uses on
  // its dashboards (see ColorUtils.brandGradient).

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return ColorUtils.brandDarkBlue;
      case 'guru':
      case 'teacher':
        return ColorUtils.brandCobalt;
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return ColorUtils.brandAzure;
      case 'staff':
        return ColorUtils.brandCobalt;
      default:
        return ColorUtils.brandCobalt;
    }
  }

  IconData _roleIconData(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Icons.shield_outlined;
      case 'guru':
      case 'teacher':
        return Icons.school_outlined;
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return Icons.family_restroom_rounded;
      case 'staff':
        return Icons.work_outline_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  /// Static stat captions per role — keeps the cards visually balanced
  /// even when the backend doesn't ship per-role counters at the role-
  /// selection step. When real metrics become available (post-login
  /// dashboard payload), we can swap these for live numbers without
  /// touching the picker.
  List<String> _roleStatsFor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return const ['Kelola siswa, guru, jadwal', 'Akses laporan keuangan'];
      case 'guru':
      case 'teacher':
        return const ['Ajar & nilai', 'Tulis rekomendasi'];
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return const ['Pantau anak', 'Terima rekomendasi'];
      case 'staff':
        return const ['Akses tugas staf'];
      default:
        return const [];
    }
  }

  // ─── OTP ────────────────────────────────────────────────────────

  Widget buildOtpForm(AuthState authState) {
    if (authState.otpCode != null &&
        otpController.text.isEmpty &&
        authState.otpCode!.isNotEmpty) {
      otpController.text = authState.otpCode!;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.otpVerification.tr,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: ColorUtils.slate900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${AppLocalizations.otpSentToEmail.tr} ${authState.currentEmail ?? ''}',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.enterOtpDigits.tr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        _buildOtpTextField(),
        const SizedBox(height: AppSpacing.xl),
        _buildOtpVerifyButton(authState),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
            child: Text(
              AppLocalizations.backToLogin.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandCobalt,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpTextField() {
    return TextField(
      controller: otpController,
      decoration: InputDecoration(
        labelText: AppLocalizations.otpCode.tr,
        border: const OutlineInputBorder(),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 8),
      autofocus: true,
    );
  }

  Widget _buildOtpVerifyButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : handleOtpVerification,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: ColorUtils.brandCobalt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                AppLocalizations.verify.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget buildLoginForm(AuthState authState);

  // Expose controllers and methods for mixin usage
  TextEditingController get emailController;
  TextEditingController get passwordController;
  TextEditingController get otpController;
  Future<void> handleOtpVerification();
  Future<void> handleLogin();
  Future<void> handleGoogleSignIn();
  String getRoleDescription(String role);
  String getRoleDisplayName(String role);
  Widget getRoleIcon(String role);
}

// ─── School picker (Frame D) ────────────────────────────────────────

class _SchoolPickerStep extends StatefulWidget {
  final AuthState authState;
  final Future<void> Function(String schoolId) onConfirm;
  final VoidCallback onBackToLogin;

  const _SchoolPickerStep({
    required this.authState,
    required this.onConfirm,
    required this.onBackToLogin,
  });

  @override
  State<_SchoolPickerStep> createState() => _SchoolPickerStepState();
}

class _SchoolPickerStepState extends State<_SchoolPickerStep> {
  String? _candidateSchoolId;
  String _query = '';

  String? _firstAvailableId() {
    final list = widget.authState.schoolList;
    if (list.isEmpty) return null;
    final first = list.first;
    return first['school_id']?.toString();
  }

  List<Map<String, dynamic>> get _filtered {
    final list = widget.authState.schoolList
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list.where((s) {
      final n = (s['school_name'] ?? '').toString().toLowerCase();
      final a = (s['address'] ?? '').toString().toLowerCase();
      return n.contains(q) || a.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        widget.authState.userData?['name'] ??
        widget.authState.userData?['nama'] ??
        'User';
    final total = widget.authState.schoolList.length;
    final candidateId = _candidateSchoolId ?? _firstAvailableId();
    final filtered = _filtered;
    final utama = filtered
        .where((s) => s['school_id']?.toString() == candidateId)
        .toList();
    final lainnya = filtered
        .where((s) => s['school_id']?.toString() != candidateId)
        .toList();

    String? candidateName;
    if (candidateId != null) {
      final hit = widget.authState.schoolList.cast<Map>().firstWhere(
        (s) => s['school_id']?.toString() == candidateId,
        orElse: () => const {},
      );
      candidateName = hit['school_name']?.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PickerHeader(
          kicker: 'HALO, ${userName.toString().toUpperCase()}',
          title: 'Pilih Sekolah',
          subtitle: total <= 1
              ? 'Lanjutkan ke sekolah Anda'
              : 'Anda terdaftar di $total sekolah · pilih untuk melanjutkan',
          stepDots: const _StepDots(active: 1, total: 3),
        ),
        const SizedBox(height: 14),
        _SearchBar(
          hint: 'Cari nama sekolah...',
          onChanged: (v) => setState(() => _query = v),
        ),
        if (utama.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionLabel('UTAMA'),
          const SizedBox(height: 6),
          for (final s in utama) _SchoolCard(school: s, active: true),
        ],
        if (lainnya.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionLabel(utama.isEmpty ? 'PILIH SEKOLAH' : 'SEKOLAH LAIN'),
          const SizedBox(height: 6),
          for (final s in lainnya)
            _SchoolCard(
              school: s,
              active: false,
              onTap: () => setState(
                () => _candidateSchoolId = s['school_id']?.toString(),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _PickerFooterCta(
          primaryLabel: candidateName == null
              ? 'Lanjutkan'
              : 'Lanjutkan ke ${_shorten(candidateName)}',
          primaryEnabled: candidateId != null && !widget.authState.isLoading,
          isLoading: widget.authState.isLoading,
          onPrimary: () async {
            if (candidateId != null) {
              await widget.onConfirm(candidateId);
            }
          },
          onSecondary: widget.onBackToLogin,
        ),
      ],
    );
  }

  String _shorten(String name) {
    if (name.length <= 28) return name;
    return '${name.substring(0, 26)}…';
  }
}

class _SchoolCard extends StatelessWidget {
  final Map<String, dynamic> school;
  final bool active;
  final VoidCallback? onTap;

  const _SchoolCard({required this.school, required this.active, this.onTap});

  String get _name => (school['school_name'] ?? '-').toString();

  String get _meta {
    final city = school['city']?.toString().trim();
    final year = school['academic_year']?.toString().trim();
    final addr = school['address']?.toString().trim();
    final parts = <String>[];
    if (city != null && city.isNotEmpty) {
      parts.add(city);
    } else if (addr != null && addr.isNotEmpty) {
      parts.add(addr);
    }
    if (year != null && year.isNotEmpty) {
      parts.add('TP $year');
    }
    return parts.join(' · ');
  }

  List<String> get _roles {
    final raw = school['roles'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Deterministic gradient picked from the school name's first
  /// letter — gives each school its own logo tile without needing
  /// the backend to ship a colour token.
  List<Color> _gradientFor(String name) {
    final c = name.isEmpty ? 'A' : name[0].toUpperCase();
    final idx = c.codeUnitAt(0) % 4;
    switch (idx) {
      case 0:
        return [ColorUtils.brandDarkBlue, ColorUtils.brandCobalt];
      case 1:
        return [const Color(0xFF0D9488), const Color(0xFF14B8A6)];
      case 2:
        return [const Color(0xFFB45309), const Color(0xFFD97706)];
      default:
        return [ColorUtils.brandCobalt, ColorUtils.brandAzure];
    }
  }

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? ColorUtils.brandCobalt : ColorUtils.slate200,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ColorUtils.brandCobalt.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradientFor(_name),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    if (_meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _meta,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_roles.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [for (final r in _roles) _RolePill(role: r)],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (active)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: ColorUtils.brandCobalt,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;

  const _RolePill({required this.role});

  Color _color() {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return ColorUtils.brandDarkBlue;
      case 'guru':
      case 'teacher':
        return ColorUtils.brandCobalt;
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return ColorUtils.brandAzure;
      default:
        return ColorUtils.slate500;
    }
  }

  String _label() {
    switch (role.toLowerCase()) {
      case 'administrator':
        return 'ADMIN';
      case 'teacher':
        return 'GURU';
      case 'parent':
      case 'orang_tua':
        return 'WALI';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Role picker (Frame E) ──────────────────────────────────────────

class _RolePickerStep extends StatefulWidget {
  final AuthState authState;
  final String Function(String role) getRoleDisplayName;
  final String Function(String role) getRoleDescription;
  final Color Function(String role) getRoleColor;
  final IconData Function(String role) getRoleIconData;
  final List<String> Function(String role) getRoleStats;
  final Future<void> Function(String role) onConfirm;
  final VoidCallback onBackToLogin;

  const _RolePickerStep({
    required this.authState,
    required this.getRoleDisplayName,
    required this.getRoleDescription,
    required this.getRoleColor,
    required this.getRoleIconData,
    required this.getRoleStats,
    required this.onConfirm,
    required this.onBackToLogin,
  });

  @override
  State<_RolePickerStep> createState() => _RolePickerStepState();
}

class _RolePickerStepState extends State<_RolePickerStep> {
  String? _candidateRole;

  String? _firstRole() {
    final list = widget.authState.roleList;
    if (list.isEmpty) return null;
    return list.first.toString();
  }

  @override
  Widget build(BuildContext context) {
    final schoolName =
        widget.authState.selectedSchool?['school_name'] ??
        widget.authState.selectedSchool?['name'] ??
        widget.authState.selectedSchool?['nama_sekolah'] ??
        widget.authState.userData?['school_name'] ??
        widget.authState.userData?['nama_sekolah'] ??
        '-';
    final roles = widget.authState.roleList
        .map((r) => r.toString())
        .toList(growable: false);
    final candidate = _candidateRole ?? _firstRole();
    final candidateColor = candidate == null
        ? ColorUtils.brandCobalt
        : widget.getRoleColor(candidate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PickerHeader(
          kicker: schoolName.toString().toUpperCase(),
          title: 'Pilih Peran',
          subtitle: roles.length <= 1
              ? 'Lanjutkan sebagai…'
              : 'Anda memiliki ${roles.length} peran di sekolah ini.',
          stepDots: const _StepDots(active: 2, total: 3),
        ),
        const SizedBox(height: 14),
        for (final r in roles)
          _RoleCard(
            role: r,
            label: widget.getRoleDisplayName(r),
            description: widget.getRoleDescription(r),
            stats: widget.getRoleStats(r),
            color: widget.getRoleColor(r),
            icon: widget.getRoleIconData(r),
            active: candidate == r,
            onTap: () => setState(() => _candidateRole = r),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ColorUtils.slate200,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anda dapat berpindah peran kapan saja dari menu profil.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PickerFooterCta(
          primaryLabel: candidate == null
              ? 'Lanjutkan'
              : 'Lanjut Sebagai ${widget.getRoleDisplayName(candidate)}',
          primaryEnabled: candidate != null && !widget.authState.isLoading,
          primaryColor: candidateColor,
          isLoading: widget.authState.isLoading,
          onPrimary: () async {
            if (candidate != null) {
              await widget.onConfirm(candidate);
            }
          },
          onSecondary: widget.onBackToLogin,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final String label;
  final String description;
  final List<String> stats;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.label,
    required this.description,
    required this.stats,
    required this.color,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? color : ColorUtils.slate200,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Left accent bar in the role's own colour — admin navy /
              // guru cobalt / wali azure per the brand tokens.
              Positioned.fill(
                left: 0,
                right: null,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: ColorUtils.slate900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate500,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (active)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: ColorUtils.slate400,
                          ),
                      ],
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in stats)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ColorUtils.slate200),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared bits ────────────────────────────────────────────────────

class _PickerHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String subtitle;
  final Widget? stepDots;

  const _PickerHeader({
    required this.kicker,
    required this.title,
    required this.subtitle,
    this.stepDots,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            kicker,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ColorUtils.slate900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate500,
              height: 1.45,
            ),
          ),
        ),
        if (stepDots != null) ...[const SizedBox(height: 10), stepDots!],
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final int active; // 0-based or 1-based — we treat as 1-based.
  final int total;

  const _StepDots({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? ColorUtils.brandCobalt : ColorUtils.slate200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate500,
        letterSpacing: 1,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(fontSize: 12.5, color: ColorUtils.slate900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: ColorUtils.slate400,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 16,
          color: ColorUtils.slate400,
        ),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: BorderSide(color: ColorUtils.brandCobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

/// Sticky-style footer rendered inline below the picker list. The
/// outer form-card already gives us a bottom-of-screen feel since the
/// brand band sits above and the page background sits below, so we
/// don't need to use `Scaffold.bottomNavigationBar` here.
class _PickerFooterCta extends StatelessWidget {
  final String primaryLabel;
  final bool primaryEnabled;
  final bool isLoading;
  final Color? primaryColor;
  final Future<void> Function() onPrimary;
  final VoidCallback onSecondary;

  const _PickerFooterCta({
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.isLoading,
    required this.onPrimary,
    required this.onSecondary,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = primaryColor ?? ColorUtils.brandCobalt;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: primaryEnabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [base, _lighten(base)],
                    )
                  : LinearGradient(
                      colors: [ColorUtils.slate300, ColorUtils.slate300],
                    ),
              boxShadow: primaryEnabled
                  ? [
                      BoxShadow(
                        color: base.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: primaryEnabled ? () => onPrimary() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Memproses…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onSecondary,
          child: Text(
            AppLocalizations.backToLogin.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandCobalt,
            ),
          ),
        ),
      ],
    );
  }

  Color _lighten(Color c) {
    // A consistent 18% lightness bump so the gradient still reads as
    // "depth" without going past the brand swatch on either end.
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
  }
}
