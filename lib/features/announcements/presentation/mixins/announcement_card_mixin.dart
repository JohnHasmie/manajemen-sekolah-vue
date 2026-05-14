// Phase 3 brand-aligned announcement card.
//
// Layout (per Parent_Phase3_Pengumuman_Mockup.svg):
//   ┌─────────────────────────────────────────────┐
//   │  ⊙   Sekolah · Kepala Sekolah    2 jam lalu │  ← top row (caption + ago)
//   │      Libur HUT Sekolah · 30 Oktober         │  ← title (slate-900 700)
//   │      Kegiatan belajar diliburkan…           │  ← preview (slate-600, 2 lines)
//   │      ▮Penting  📎 Surat-edaran.pdf          │  ← chips row (optional)
//   └─────────────────────────────────────────────┘
//                                              • ← unread dot (azure)
//
// The avatar is a round 36×36 tinted circle:
//   • Penting     → red bg, warning icon
//   • Sekolah     → blue bg, creator initials text
//   • Kelas       → emerald bg, creator initials text
//   • Default     → violet bg, creator initials text
//
// Source caption is parsed from `role_target` + creator name:
//   • role_target=='all'  → "Sekolah · {creator name or role}"
//   • class_id != null    → "Kelas {class name} · {creator name}"
//   • else                → "{role_target} · {creator name}"
//
// Attachment indicator (📎 + filename) appears whenever the announcement
// has a `file_path` / `file_name`. Status pill ("Penting") still appears
// for high-priority items.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for building announcement card widgets.
mixin AnnouncementCardMixin on ConsumerState<ParentAnnouncementScreen> {
  Color getPrimaryColor();

  Widget buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
    void Function(Map<String, dynamic>) onTap,
  ) {
    final isUnread = _isUnread(announcementData);
    final isImportant = _isImportant(announcementData);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(announcementData),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: _buildCardInner(announcementData, isImportant, isUnread),
        ),
      ),
    );
  }

  Widget _buildCardInner(
    Map<String, dynamic> announcementData,
    bool isImportant,
    bool isUnread,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: _cardDecoration(),
          child: _buildCardRow(announcementData, isImportant),
        ),
        if (isUnread) Positioned(top: 12, right: 12, child: _buildUnreadDot()),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      border: Border.all(color: ColorUtils.slate200, width: 0.75),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    );
  }

  Widget _buildCardRow(
    Map<String, dynamic> announcementData,
    bool isImportant,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(announcementData, isImportant),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildCardContent(announcementData, isImportant)),
      ],
    );
  }

  bool _isUnread(Map<String, dynamic> data) {
    return !Announcement.fromJson(data).isRead;
  }

  bool _isImportant(Map<String, dynamic> data) {
    return ['penting', 'important'].contains(data['priority']);
  }

  /// Round 36-px avatar tinted by source category. Penting items get a
  /// red warning icon; everything else gets the creator's initials.
  Widget _buildAvatar(Map<String, dynamic> data, bool isImportant) {
    final palette = _avatarPalette(data, isImportant);
    final initials = _initials(_creatorName(data));

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: palette.bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: isImportant
          ? Icon(Icons.priority_high_rounded, color: palette.fg, size: 18)
          : Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.fg,
                height: 1.0,
                letterSpacing: 0.2,
              ),
            ),
    );
  }

  ({Color bg, Color fg}) _avatarPalette(
    Map<String, dynamic> data,
    bool isImportant,
  ) {
    if (isImportant) {
      return (bg: ColorUtils.errorLight, fg: ColorUtils.error600);
    }
    final hasClass = (data['class_id'] ?? '').toString().isNotEmpty;
    final roleTarget = (data['role_target'] ?? '').toString().toLowerCase();

    if (hasClass) {
      // Tailwind green-100 / green-700 — feature-local category tone for
      // class-targeted announcements; no direct ColorUtils token yet.
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
    }
    if (roleTarget == 'all' ||
        roleTarget == 'wali' ||
        roleTarget == 'orang_tua') {
      return (bg: ColorUtils.corporateBlue100, fg: ColorUtils.corporateBlue700);
    }
    // Tailwind violet-100 / violet-700 — feature-local default tone for
    // generic announcements; no direct ColorUtils token yet.
    return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
  }

  Widget _buildCardContent(
    Map<String, dynamic> announcementData,
    bool isImportant,
  ) {
    final model = Announcement.fromJson(announcementData);
    final dateLabel = _formatRelativeDate(model.createdAt);
    final source = _sourceCaption(announcementData);
    final attachment = _attachmentName(announcementData);
    final hasChipRow = isImportant || attachment != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: source caption + relative timestamp.
        Row(
          children: [
            Expanded(
              child: Text(
                source,
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
            // Reserve space for the unread dot positioned in the Stack.
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                dateLabel,
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
          model.title.isNotEmpty ? model.title : 'Tanpa judul',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (model.content.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _stripHtml(model.content),
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
        if (hasChipRow) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (isImportant) _buildImportantPill(),
              if (isImportant && attachment != null) const SizedBox(width: 8),
              if (attachment != null)
                Flexible(child: _buildAttachmentChip(attachment)),
            ],
          ),
        ],
      ],
    );
  }

  /// Red dot+label pill matching the mockup ("●Penting").
  Widget _buildImportantPill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: ColorUtils.errorLight,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ColorUtils.error600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Penting',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.errorDark,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Paperclip + filename, slate-500 hairline meta row.
  Widget _buildAttachmentChip(String fileName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file_rounded, size: 13, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _creatorName(Map<String, dynamic> data) {
    final raw =
        data['pembuat_nama'] ??
        data['creator_name'] ??
        (data['creator'] is Map ? (data['creator'] as Map)['name'] : null);
    return (raw ?? '').toString().trim();
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  /// Composes "Sekolah · Kepala Sekolah" / "Kelas 8B · Bu Sari" caption.
  String _sourceCaption(Map<String, dynamic> data) {
    final creator = _creatorName(data);
    final hasClass = (data['class_id'] ?? '').toString().isNotEmpty;
    final classLabel =
        (data['class_name'] ??
                (data['class'] is Map
                    ? (data['class'] as Map)['name']
                    : null) ??
                '')
            .toString();
    final roleTarget = (data['role_target'] ?? '').toString().toLowerCase();

    String prefix;
    if (hasClass) {
      prefix = classLabel.isNotEmpty ? 'Kelas $classLabel' : 'Kelas';
    } else if (roleTarget == 'wali' || roleTarget == 'orang_tua') {
      prefix = 'Wali';
    } else if (roleTarget == 'all' || roleTarget.isEmpty) {
      prefix = 'Sekolah';
    } else {
      prefix = roleTarget[0].toUpperCase() + roleTarget.substring(1);
    }

    if (creator.isEmpty) return prefix;
    return '$prefix · $creator';
  }

  String? _attachmentName(Map<String, dynamic> data) {
    final filePath = (data['file_path'] ?? data['file'] ?? '').toString();
    if (filePath.isEmpty) return null;
    final name = (data['file_name'] ?? '').toString();
    if (name.isNotEmpty) return name;
    final segments = filePath.split('/');
    return segments.isNotEmpty ? segments.last : null;
  }

  /// Strip HTML tags from rich-text content for the preview line.
  String _stripHtml(String html) {
    if (html.isEmpty) return html;
    final stripped = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped;
  }

  /// Compact relative date for the meta row.
  /// Examples: "Baru saja", "30 menit lalu", "3 jam lalu", "Kemarin",
  /// "13 Apr 14:32" (older than a week).
  String _formatRelativeDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final parsed = DateTime.tryParse(dateString);
    if (parsed == null) return '';
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
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
    return '${parsed.day} ${months[parsed.month - 1]} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  /// Azure dot in the top-right corner of the card. Mockup uses
  /// brand-azure-deep, not error-red — matches every other Phase-3
  /// unread indicator (notifications, billing, activity feed).
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
