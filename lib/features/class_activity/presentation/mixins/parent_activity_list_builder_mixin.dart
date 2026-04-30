// Parent class-activity list — Phase 3 brand-aligned redesign.
//
// Layout (per Parent_Phase3_AktivitasKelas_Mockup.svg):
//   ┌──────────────────────────────────────────────┐
//   │ HARI INI                                     │  ← date section
//   │ ┌──────────────────────────────────────────┐ │
//   │ │  ⊙   Bu Sari · Wali kelas    Hari ini    │ │  ← caption + ago
//   │ │      Praktikum IPA — Sistem Pernapasan   │ │  ← title (700)
//   │ │      [Praktikum]                         │ │  ← type pill
//   │ │      Anak-anak melakukan eksperimen…     │ │  ← preview (2 lines)
//   │ │      📚 Bab 4 · Sistem Pernapasan        │ │  ← chapter (optional)
//   │ │      ────────────────────────────        │ │
//   │ │      🛡 Khusus  ⭐ Untuk anak ini         │ │  ← key chips only
//   │ └──────────────────────────────────────────┘ │
//   │ 27 OKTOBER 2025                               │
//   │ ...                                           │
//   └──────────────────────────────────────────────┘
//
// Avatar palette routes by `jenis`:
//   • tugas  → amber bg / amber-700 fg  (Tugas pill amber)
//   • materi → emerald bg / emerald-700 fg (Materi pill green)
//
// Activities are grouped by `tanggal` with sticky-style section
// headers ("HARI INI", "KEMARIN", "29 OKTOBER 2025"). Read tracking
// is preserved — onItemVisible is still called for every activity
// during build, just inside the new card chrome.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

mixin ParentActivityListBuilderMixin
    on ConsumerState<ParentClassActivityScreen> {
  Widget buildActivityList() {
    final lang = ref.read(languageRiverpod);
    final state = this as ParentClassActivityScreenState;

    if (state.selectedStudentId == null) {
      return BrandEmptyState(
        icon: Icons.face_retouching_natural_rounded,
        tone: BrandEmptyStateTone.info,
        kicker: 'Pilih anak',
        title: 'Pilih anak terlebih dahulu',
        message: AppLocalizations.selectChildToViewActivity.tr,
      );
    }

    if (state.isLoading) {
      return buildLoadingState();
    }

    if (state.activityList.isEmpty) {
      return BrandEmptyState(
        icon: Icons.event_note_outlined,
        tone: BrandEmptyStateTone.info,
        kicker: 'Belum ada data',
        title: 'Belum ada aktivitas',
        message: AppLocalizations.noActivityForChild.tr,
        secondaryAction: BrandEmptyStateAction(
          label: 'Muat ulang',
          icon: Icons.refresh_rounded,
          onTap: () => state.forceRefresh(),
        ),
      );
    }

    // Group activities by their date string (yyyy-MM-dd). Falls back
    // to created_at / today when `tanggal` is missing so the screen
    // never produces an empty group key.
    final groups = _groupByDate(state.activityList);
    final orderedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: orderedKeys.length,
      itemBuilder: (context, gIdx) {
        final key = orderedKeys[gIdx];
        final dayItems = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, gIdx == 0 ? 6 : 18, 24, 8),
              child: Text(
                _dateHeaderLabel(key),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final activity in dayItems)
              Builder(
                builder: (context) {
                  onItemVisible(activity);
                  return _ActivityCard(
                    activity: activity,
                    lang: lang,
                    isUnread: !_isRead(state, activity),
                    onTap: () => showActivityDetail(activity),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<dynamic> activities,
  ) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final raw in activities) {
      final a = raw as Map<String, dynamic>;
      final key = _activityDateKey(a);
      out.putIfAbsent(key, () => []).add(a);
    }
    return out;
  }

  String _activityDateKey(Map<String, dynamic> a) {
    final raw = (a['tanggal'] ?? a['created_at'] ?? '').toString();
    if (raw.isEmpty) {
      final now = DateTime.now();
      return _ymd(now);
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.split('T').first;
    return _ymd(parsed);
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _dateHeaderLabel(String ymd) {
    final parsed = DateTime.tryParse(ymd);
    if (parsed == null) return ymd.toUpperCase();
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final p0 = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = t0.difference(p0).inDays;
    if (diff == 0) return 'HARI INI';
    if (diff == 1) return 'KEMARIN';
    const months = [
      'JANUARI',
      'FEBRUARI',
      'MARET',
      'APRIL',
      'MEI',
      'JUNI',
      'JULI',
      'AGUSTUS',
      'SEPTEMBER',
      'OKTOBER',
      'NOVEMBER',
      'DESEMBER',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  bool _isRead(ParentClassActivityScreenState state, Map<String, dynamic> a) {
    if (!state.hasFreshData) return true;
    final raw = a['is_read'];
    return raw == true || raw == 1 || raw == '1';
  }

  Widget buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 3,
      shrinkWrap: true,
      baseColor: getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  String formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Color getPrimaryColor();

  void showActivityDetail(Map<String, dynamic> activity);

  void onItemVisible(Map<String, dynamic> activity);
}

/// Single activity card. Pulled out as a stateless widget so it can
/// own its own private helpers (palette, time-ago, detail row) without
/// polluting the mixin namespace.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.lang,
    required this.isUnread,
    required this.onTap,
  });

  final Map<String, dynamic> activity;
  final LanguageProvider lang;
  final bool isUnread;
  final VoidCallback onTap;

  bool get _isAssignment => activity['jenis'] == 'tugas';
  bool get _isSpecificTarget => activity['target'] == 'khusus';
  bool get _isForThisStudent => activity['untuk_siswa_ini'] == true;

  ({Color bg, Color fg}) get _palette {
    return _isAssignment
        ? (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309))
        : (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: ColorUtils.slate200, width: 0.75),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                ),
                child: _buildContent(),
              ),
              if (isUnread)
                Positioned(top: 12, right: 12, child: _buildUnreadDot()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final subject =
        (activity['mata_pelajaran_nama'] ??
                (activity['subject'] is Map
                    ? (activity['subject'] as Map)['name']
                    : null) ??
                '')
            .toString();
    final klass =
        (activity['kelas_nama'] ??
                (activity['class'] is Map
                    ? (activity['class'] as Map)['name']
                    : null) ??
                '')
            .toString();
    final teacher =
        (activity['guru_nama'] ??
                (activity['teacher'] is Map
                    ? (activity['teacher'] as Map)['name']
                    : null) ??
                '')
            .toString();
    final caption = _composeCaption(subject, klass, teacher);
    final initials = _initials(subject.isNotEmpty ? subject : teacher);
    final timeAgo = _timeAgo(activity['tanggal'] ?? activity['created_at']);
    final description = (activity['deskripsi'] ?? '').toString();
    final hasDescription = description.isNotEmpty && description != 'null';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Round 36px source-tinted avatar with subject initials.
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: _palette.bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _palette.fg,
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caption + timestamp row.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate400,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (activity['judul'] ?? AppLocalizations.activityTitle.tr)
                    .toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _typePill(),
              if (hasDescription) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_chapterLabel() != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 13,
                      color: ColorUtils.slate400,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _chapterLabel()!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorUtils.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (_hasFooterChips()) ...[
                const SizedBox(height: 10),
                Container(height: 1, color: ColorUtils.slate100),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: _footerChips()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _composeCaption(String subject, String klass, String teacher) {
    final parts = <String>[];
    if (subject.isNotEmpty) parts.add(subject);
    if (klass.isNotEmpty) parts.add('Kelas $klass');
    if (teacher.isNotEmpty) parts.add(teacher);
    if (parts.isEmpty) return _isAssignment ? 'Tugas' : 'Materi';
    return parts.join(' · ');
  }

  String _initials(String text) {
    if (text.isEmpty) return _isAssignment ? 'TG' : 'MT';
    final parts = text
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return _isAssignment ? 'TG' : 'MT';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  /// Inline tinted pill — "Tugas" amber or "Materi" green, matching mockup.
  Widget _typePill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: _palette.bg,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        _isAssignment
            ? AppLocalizations.assignment.tr
            : AppLocalizations.material.tr,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _palette.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String? _chapterLabel() {
    final bab =
        (activity['judul_bab'] ??
                (activity['chapter'] is Map
                    ? (activity['chapter'] as Map)['title']
                    : null) ??
                '')
            .toString();
    final subBab =
        (activity['judul_sub_bab'] ??
                (activity['subChapter'] is Map
                    ? (activity['subChapter'] as Map)['title']
                    : null) ??
                '')
            .toString();
    if (bab.isEmpty && subBab.isEmpty) return null;
    if (bab.isEmpty) return subBab;
    if (subBab.isEmpty) return bab;
    return '$bab · $subBab';
  }

  bool _hasFooterChips() {
    final hasDue = _isAssignment && activity['batas_waktu'] != null;
    return _isSpecificTarget || hasDue;
  }

  List<Widget> _footerChips() {
    final chips = <Widget>[];
    if (_isSpecificTarget) {
      chips.add(
        _chip(
          icon: Icons.shield_outlined,
          label: lang.getTranslatedText({'en': 'Specific', 'id': 'Khusus'}),
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF0369A1),
        ),
      );
    }
    if (_isSpecificTarget && _isForThisStudent) {
      chips.add(
        _chip(
          icon: Icons.star_rounded,
          label: lang.getTranslatedText({
            'en': 'For this child',
            'id': 'Untuk anak ini',
          }),
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1D4ED8),
        ),
      );
    }
    if (_isAssignment && activity['batas_waktu'] != null) {
      chips.add(
        _chip(
          icon: Icons.access_time_rounded,
          label:
              '${lang.getTranslatedText({'en': 'Due', 'id': 'Batas'})}: '
              '${AppDateUtils.formatDateString(activity['batas_waktu'].toString(), format: 'dd MMM')}',
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFF991B1B),
        ),
      );
    }
    return chips;
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.isEmpty) return '';
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return s;
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) {
      // Same calendar day → show "Hari ini · HH:mm"
      final t0 = DateTime(now.year, now.month, now.day);
      final p0 = DateTime(parsed.year, parsed.month, parsed.day);
      if (t0 == p0) {
        return 'Hari ini · '
            '${parsed.hour.toString().padLeft(2, '0')}:'
            '${parsed.minute.toString().padLeft(2, '0')}';
      }
      return '${diff.inHours} jam lalu';
    }
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }

  Widget _buildUnreadDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: ColorUtils.brandAzureDeep,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.brandAzureDeep.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
