// School picker (Frame D of
// `_design/auth_login_school_role_redesign.html`). Renders the search
// bar, UTAMA + SEKOLAH LAIN sections, gradient logo cards with a role
// pill row, and the sticky "Lanjutkan ke …" footer.
//
// Tracks a *candidate* selection locally (UTAMA highlight + cobalt CTA)
// and only fires the network call on the Lanjutkan tap, matching the
// mockup's two-step pattern.
//
// Extracted from `auth_form_builder_mixin.dart` as part of a structural
// readability split — behavior is unchanged.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/auth_picker_shared.dart';

class SchoolPickerStep extends StatefulWidget {
  final AuthState authState;
  final Future<void> Function(String schoolId) onConfirm;
  final VoidCallback onBackToLogin;

  const SchoolPickerStep({
    super.key,
    required this.authState,
    required this.onConfirm,
    required this.onBackToLogin,
  });

  @override
  State<SchoolPickerStep> createState() => _SchoolPickerStepState();
}

class _SchoolPickerStepState extends State<SchoolPickerStep> {
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
        .map(Map<String, dynamic>.from)
        .toList();
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list.where((s) {
      // Backend renamed `schools.school_name` → `schools.name`.
      final n = (s['school_name'] ?? s['name'] ?? '').toString().toLowerCase();
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
      candidateName = (hit['school_name'] ?? hit['name'])?.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PickerHeader(
          kicker: '${kAutHello.tr}${userName.toString().toUpperCase()}',
          title: kAutSelectSchoolTitle.tr,
          subtitle: total <= 1
              ? kAutProceedSchool.tr
              : kAutRegisteredSchools.tr.replaceAll(
                  '\$total',
                  total.toString(),
                ),
          stepDots: const StepDots(active: 1, total: 3),
        ),
        const SizedBox(height: 14),
        PickerSearchBar(
          hint: kAutSearchSchool.tr,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (utama.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionLabel(kAutMainSchool.tr),
          const SizedBox(height: 6),
          for (final s in utama) _SchoolCard(school: s, active: true),
        ],
        if (lainnya.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionLabel(
            utama.isEmpty ? kAutSelectSchoolSection.tr : kAutOtherSchools.tr,
          ),
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
        PickerFooterCta(
          primaryLabel: candidateName == null
              ? kAutContinue.tr
              : '${kAutContinueTo.tr}${_shorten(candidateName)}',
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

  String get _name =>
      (school['school_name'] ?? school['name'] ?? '-').toString();

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
      parts.add('${kAutAcademicYear.tr}$year');
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
        return kAutRoleAdmin.tr;
      case 'teacher':
        return kAutRoleTeacher.tr;
      case 'parent':
      case 'orang_tua':
        return kAutRoleParent.tr;
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
